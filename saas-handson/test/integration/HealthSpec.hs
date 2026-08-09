{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module HealthSpec (spec) where

import Auth.Server (mkJWKStore)
import Crypto.JWT (JWKSet (..))
import Logging.Capturing (newCapturingLogger)
import Network.Wai (Application)
import Server (mkApp)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)
import User.Repository.InMemory (newInMemoryUserRepository)

-- | /healthはAuthProtectの対象外（Health.APIにAuthProtectを付けていない）
-- なので、鍵を1つも含まない空のJWKStoreを渡しても認証エラーにならない。
-- UserRepository・LoggerはいずれもHealthの検証には使われないため、
-- 軽量なin-memory実装・Capturing実装で十分。
spec :: Spec
spec = with mkAppForTest $
  describe "GET /health" $ do
    it "ステータスコード200を返す" $
      get "/health" `shouldRespondWith` 200

    it "レスポンスボディにstatus:okを含む" $
      get "/health" `shouldRespondWith` [json|{status:"ok"}|]

mkAppForTest :: IO Application
mkAppForTest = do
  (logger, _getLogs) <- newCapturingLogger
  repo <- newInMemoryUserRepository
  pure (mkApp (mkJWKStore (JWKSet [])) logger repo)
