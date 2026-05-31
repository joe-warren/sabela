{-# LANGUAGE OverloadedStrings #-}

{- | Pure URL helpers for the import-from-URL feature. The only export
rewrites a human-facing GitHub/gist URL to the @raw@ form that actually
serves file bytes, so a user can paste the address straight from their
browser. Anything that isn't a recognised GitHub page is returned
untouched. Kept pure (like 'Sabela.Server.Static.safeUploadName') so it
is unit-testable without a network.
-}
module Sabela.Url (
    rewriteGitHubUrl,
) where

import Data.Text (Text)
import qualified Data.Text as T

{- | Rewrite a GitHub @blob@ page or a gist page to its raw download URL:

  * @https:\/\/github.com\/o\/r\/blob\/ref\/path@
    → @https:\/\/raw.githubusercontent.com\/o\/r\/ref\/path@
  * @https:\/\/gist.github.com\/user\/id@ → same with @\/raw@ appended

Already-raw URLs (@raw.githubusercontent.com@, a gist @…\/raw@) and every
non-GitHub URL pass through unchanged. Query strings and @#@ fragments are
dropped only on the rewritten GitHub forms (the raw host ignores them);
other URLs keep theirs verbatim.
-}
rewriteGitHubUrl :: Text -> Text
rewriteGitHubUrl url = case parseHostPath trimmed of
    Just ("github.com", a : b : "blob" : ref : p1 : rest) ->
        "https://raw.githubusercontent.com/"
            <> T.intercalate "/" (a : b : ref : p1 : rest)
    Just ("gist.github.com", segs)
        | length segs == 2 ->
            "https://gist.github.com/" <> T.intercalate "/" segs <> "/raw"
    _ -> trimmed
  where
    trimmed = T.strip url

{- | Split a URL into its host and the non-empty path segments, dropping the
scheme plus any @?query@ / @#fragment@ tail. 'Nothing' when there is no host.
-}
parseHostPath :: Text -> Maybe (Text, [Text])
parseHostPath u =
    let noScheme = dropScheme u
        (host, rest) = T.breakOn "/" noScheme
        rawPath = T.drop 1 rest
        path = T.takeWhile (\c -> c /= '?' && c /= '#') rawPath
        segs = filter (not . T.null) (T.splitOn "/" path)
     in if T.null host then Nothing else Just (host, segs)

dropScheme :: Text -> Text
dropScheme u
    | "https://" `T.isPrefixOf` u = T.drop 8 u
    | "http://" `T.isPrefixOf` u = T.drop 7 u
    | otherwise = u
