{-# LANGUAGE OverloadedStrings #-}

module Sabela.Dashboard (
    renderStaticDashboard,
) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

import Data.Aeson (encode)
import Sabela.Model (Notebook)

{- | Render a standalone dashboard HTML by injecting notebook JSON
into the dashboard template. The template contains a placeholder
@/*__SABELA_INJECT__*\/@ which is replaced with a JSON assignment.

Every @\</@ in the JSON is rewritten to @\<\\/@ so that a @\</script\>@ in
notebook content (in any case, or followed by whitespace) cannot prematurely
close the enclosing @\<script\>@ tag. The @\\/@ is an ordinary @/@ once the JS
string is parsed, so the embedded data round-trips unchanged.
-}
renderStaticDashboard :: BS.ByteString -> Notebook -> LBS.ByteString
renderStaticDashboard template nb =
    LBS.fromStrict . TE.encodeUtf8 $ T.replace placeholder injection tmpl
  where
    tmpl :: Text
    tmpl = TE.decodeUtf8 template
    placeholder :: Text
    placeholder = "/*__SABELA_INJECT__*/"
    -- Escape every "</" so that no "</script>" (in any case, or with trailing
    -- whitespace) inside notebook content can close the enclosing <script>.
    -- "<\/" is an ordinary "</" once the JS string is parsed, so data is unchanged.
    safeJson :: Text
    safeJson =
        T.replace "</" "<\\/" (TE.decodeUtf8 (LBS.toStrict (encode nb)))
    injection :: Text
    injection =
        "window.__SABELA_STATIC__ = " <> safeJson <> ";"
