{-# LANGUAGE OverloadedStrings #-}

module HealthSpec (spec) where

import Health.Server (server)
import Health.Types (HealthResponse (..))
import Servant.Server (runHandler)
import Test.Hspec

-- | Health機能はUserに一切依存しないため、単体テストもHealth.Server.server
-- だけを直接呼び出す（トップレベルの合成済みmkServerやUser.Storeは
-- 一切必要ない）。
spec :: Spec
spec = describe "healthHandler（単体）" $
  it "statusフィールドにokを返す" $ do
    result <- runHandler server
    result `shouldBe` Right (HealthResponse "ok")
