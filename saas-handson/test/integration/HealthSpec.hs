{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module HealthSpec (spec) where

import Auth.Server (mkJWKStore)
import Crypto.JWT (JWKSet (..))
import Server (mkApp)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)
import User.Repository.InMemory (newInMemoryUserRepository)

-- | /healthはAuthProtectの対象外（Health.APIにAuthProtectを付けていない）
-- なので、鍵を1つも含まない空のJWKStoreを渡しても認証エラーにならない。
-- UserRepositoryはHealthの検証には使われないため、軽量なin-memory実装
-- で十分。
spec :: Spec
spec = with (mkApp (mkJWKStore (JWKSet [])) <$> newInMemoryUserRepository) $
  describe "GET /health" $ do
    it "ステータスコード200を返す" $
      get "/health" `shouldRespondWith` 200

    it "レスポンスボディにstatus:okを含む" $
      get "/health" `shouldRespondWith` [json|{status:"ok"}|]
