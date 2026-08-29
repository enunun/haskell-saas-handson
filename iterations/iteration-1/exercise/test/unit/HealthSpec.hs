{-# LANGUAGE OverloadedStrings #-}

module HealthSpec (spec) where

import Server (mkServer)
import Servant.Server (runHandler)
import Test.Hspec
import Types (HealthResponse (..))

-- | ハンドラの戻り値を直接検証する単体テスト。
--
-- HTTPリクエストのパース・ルーティング・JSONエンコードといったWeb層を
-- 経由せず、servant-serverが提供するrunHandlerでHandlerモナドの計算結果
-- のみを取り出して検証する。healthエンドポイントは固定値を返すのみで
-- 分岐を持たないため、この単体テストとtest/integrationの結合テストは
-- 現時点ではほぼ同じ内容になる。
spec :: Spec
spec = describe "healthHandler（単体）" $
  it "statusフィールドにokを返す" $ do
    result <- runHandler mkServer
    result `shouldBe` Right (HealthResponse "ok")
