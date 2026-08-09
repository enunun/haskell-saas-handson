{-# LANGUAGE OverloadedStrings #-}

module HealthSpec (spec) where

import Servant (( :<|> ) (..))
import Server (mkServer)
import Servant.Server (runHandler)
import Test.Hspec
import Types (HealthResponse (..))
import User.Server (newStore)

-- | ハンドラの戻り値を直接検証する単体テスト。
--
-- HTTPリクエストのパース・ルーティング・JSONエンコードといったWeb層を
-- 経由せず、servant-serverが提供するrunHandlerでHandlerモナドの計算結果
-- のみを取り出して検証する。healthエンドポイントは固定値を返すのみで
-- 分岐を持たないため、この単体テストとtest/integrationの結合テストは
-- 現時点ではほぼ同じ内容になる。ドメインロジックを持つ機能が増えた際、
-- Web層を起動せず高速に検証できる基盤として役立つ。
spec :: Spec
spec = describe "healthHandler（単体）" $
  it "statusフィールドにokを返す" $ do
    store <- newStore
    let healthHandler :<|> _rest = mkServer store
    result <- runHandler healthHandler
    result `shouldBe` Right (HealthResponse "ok")
