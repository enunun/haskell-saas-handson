{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module HealthSpec (spec) where

import Data.Proxy (Proxy (..))
import qualified Health.Api as Health
import Health.Server (server)
import Servant (serve)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)

-- | Healthの結合テストは、Health.APIだけからApplicationを組み立てる。
-- トップレベルの合成済みmkApp・User.Storeには依存しない。
spec :: Spec
spec = with (pure (serve (Proxy :: Proxy Health.API) server)) $
  describe "GET /health" $ do
    it "ステータスコード200を返す" $
      get "/health" `shouldRespondWith` 200

    it "レスポンスボディにstatus:okを含む" $
      get "/health" `shouldRespondWith` [json|{status:"ok"}|]
