{-# LANGUAGE OverloadedStrings #-}

module Sabela.Deps (
    collectMetadata,
    collectMetadataFromContent,
    mergedMeta,
    sabelaDefaultExts,
) where

import Data.Set (Set)
import qualified Data.Set as S
import Data.Text (Text)
import Sabela.Model (Cell (..), CellType (..), Notebook (..))
import qualified Sabela.SessionTypes as ST
import ScriptHs.Markdown (Segment (..), parseMarkdown)
import ScriptHs.Parser (
    CabalMeta (..),
    ScriptFile (..),
    mergeMetas,
    parseScript,
 )

collectMetadata :: Notebook -> CabalMeta
collectMetadata nb =
    let allCode =
            filter (\c -> cellType c == CodeCell && cellLang c == ST.Haskell) (nbCells nb)
     in mergeMetas [(scriptMeta . parseScript) (cellSource c) | c <- allCode]

collectMetadataFromContent :: Text -> CabalMeta
collectMetadataFromContent content =
    let segs = parseMarkdown content
        codeSrcs = [src | CodeBlock _ src _ <- segs]
     in mergeMetas (map (scriptMeta . parseScript) codeSrcs)

{- | Language extensions enabled by default in every notebook, on top of
whatever a cell declares via @-- cabal: default-extensions:@. Injected by
'mergedMeta' so the live GHCi session and both export paths agree.
-}
sabelaDefaultExts :: [Text]
sabelaDefaultExts =
    [ "TemplateHaskell"
    , "GADTs"
    , "DataKinds"
    , "OverloadedStrings"
    , "TypeApplications"
    , "ScopedTypeVariables"
    ]

{- | Fold environment-global deps and the Sabela default extensions into a
notebook's collected metadata. The single chokepoint shared by the live session
('Sabela.Handlers.Lifecycle') and the standalone / reactive exporters, so the
defaults apply uniformly. Extensions are deduped, preserving cell-declared ones.
-}
mergedMeta :: Set Text -> CabalMeta -> CabalMeta
mergedMeta globalDeps meta =
    meta
        { metaDeps = S.toList (S.fromList (metaDeps meta) <> globalDeps)
        , metaExts = S.toList (S.fromList (metaExts meta) <> S.fromList sabelaDefaultExts)
        }
