module HealthSpec (spec) where

import Server (app)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)

spec :: Spec
spec = with (pure app) $
  describe "GET /health" $ do
    it "ステータスコード200を返す" $
      get "/health" `shouldRespondWith` 200

    it "レスポンスボディにstatus:okを含む" $
      get "/health" `shouldRespondWith` [json|{status:"ok"}|]
