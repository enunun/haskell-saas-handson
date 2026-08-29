{-# LANGUAGE OverloadedStrings #-}

module Logging.StdoutSpec (spec) where

import Data.Aeson (Value, decode)
import qualified Data.ByteString.Lazy.Char8 as LBS8
import Logging (logInfo, logWarn)
import Logging.Stdout (newStdoutLogger)
import System.IO.Silently (capture_)
import Test.Hspec

-- | newStdoutLoggerが実際に標準出力へ書き込むJSON行を検証する。
-- silentlyのcapture_で、あるIOアクションの実行中に標準出力へ書かれた
-- 内容をまるごと文字列として捕捉できる（テストの実行結果そのものを
-- 汚さずに済む）。
spec :: Spec
spec = describe "Logging.Stdout.newStdoutLogger" $ do
  it "ログ1件につき1行、パース可能なJSONを出力する" $ do
    output <- capture_ $ do
      logger <- newStdoutLogger
      logInfo logger "user_created" [("tenant_id", "acme"), ("subject", "alice")]
    let ls = filter (not . null) (lines output)
    length ls `shouldBe` 1
    (decode (LBS8.pack (head ls)) :: Maybe Value) `shouldSatisfy` (/= Nothing)

  it "level・message・fieldsを含むJSONを出力する" $ do
    output <- capture_ $ do
      logger <- newStdoutLogger
      logWarn logger "user_creation_forbidden" [("tenant_id", "acme"), ("subject", "bob")]
    output `shouldContain` "\"level\":\"warn\""
    output `shouldContain` "\"message\":\"user_creation_forbidden\""
    output `shouldContain` "\"tenant_id\":\"acme\""
    output `shouldContain` "\"subject\":\"bob\""

  it "複数回ログを呼ぶと複数行出力される" $ do
    output <- capture_ $ do
      logger <- newStdoutLogger
      logInfo logger "one" []
      logInfo logger "two" []
    let ls = filter (not . null) (lines output)
    length ls `shouldBe` 2
