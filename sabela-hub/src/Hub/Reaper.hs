{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE OverloadedStrings #-}

module Hub.Reaper (
    startReaper,
    sweepOrphans,
) where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM
import Control.Exception (SomeException, try)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import Data.Time (diffUTCTime, getCurrentTime)
import Hub.Session
import Hub.Types
import System.IO (hPutStrLn, stderr)

-- | Start a background thread that stops idle sessions.
startReaper :: SessionManager -> IO ()
startReaper sm = do
    _ <- forkIO $ loop sm
    pure ()

loop :: SessionManager -> IO ()
loop sm = do
    threadDelay 60_000_000 -- 1 minute
    reapIdle sm
    loop sm

reapIdle :: SessionManager -> IO ()
reapIdle sm = do
    now <- getCurrentTime
    let timeout = hcIdleTimeout (smConfig sm)
    sessions <- readTVarIO (smSessions sm)
    let idle =
            Map.keys $
                Map.filter
                    ( \sess ->
                        sessionState sess /= SStopping
                            && diffUTCTime now (sessionLastActivity sess) > timeout
                    )
                    sessions
    mapM_ (reapOne sm) idle

reapOne :: SessionManager -> SessionId -> IO ()
reapOne sm sid = do
    hPutStrLn stderr $ "[hub] Reaping idle session " ++ sidLabel sid
    cleanupSession sm sid
  where
    sidLabel (SessionId s) = T.unpack (T.take 8 s) ++ "..."

{- | Stop any RUNNING ECS task in the configured cluster/family that is not
tracked in the session map. Intended to run once at startup so that tasks
which outlived a previous hub instance get cleaned up — the in-memory
session map is not persisted, so they would otherwise live forever.
-}
sweepOrphans :: SessionManager -> IO ()
sweepOrphans sm = do
    let cfg = hcTaskConfig (smConfig sm)
        ecs = smEcs sm
    eTasks <- try (ebListRunningTasks ecs cfg) :: IO (Either SomeException [TaskId])
    case eTasks of
        Left e ->
            hPutStrLn stderr $ "[hub] Orphan sweep skipped (list failed): " ++ show e
        Right taskIds -> do
            tracked <- trackedTaskIds sm
            let orphans = filter (`Set.notMember` tracked) taskIds
            hPutStrLn stderr $
                "[hub] Orphan sweep: "
                    ++ show (length taskIds)
                    ++ " running, "
                    ++ show (length orphans)
                    ++ " orphan(s) to stop"
            mapM_ (stopOrphan ecs cfg) orphans

trackedTaskIds :: SessionManager -> IO (Set.Set TaskId)
trackedTaskIds sm = do
    sessions <- readTVarIO (smSessions sm)
    pure $ Set.fromList [sessionTaskId s | s <- Map.elems sessions]

stopOrphan :: EcsBackend -> TaskConfig -> TaskId -> IO ()
stopOrphan ecs cfg tid@(TaskId arn) = do
    hPutStrLn stderr $ "[hub] Stopping orphan task " ++ T.unpack (T.takeEnd 12 arn)
    r <- try (ebStopTask ecs cfg tid) :: IO (Either SomeException ())
    case r of
        Left e -> hPutStrLn stderr $ "[hub] Failed to stop orphan: " ++ show e
        Right () -> pure ()
