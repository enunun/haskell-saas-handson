{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module User.UserSpec (spec) where

import Auth.Server (authContext, mkJWKStore)
import Control.Lens ((&), (?~))
import Crypto.JOSE (JOSE, JWK, KeyMaterialGenParam (RSAGenParam), bestJWSAlg, genJWK, newJWSHeaderProtected, runJOSE)
import Crypto.JWT
  ( JWKSet (..)
  , JWTError
  , NumericDate (..)
  , SignedJWT
  , addClaim
  , claimExp
  , claimSub
  , emptyClaimsSet
  , encodeCompact
  , signClaims
  )
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (Value (String))
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LBS
import Data.Proxy (Proxy (..))
import Data.Text (Text)
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Network.HTTP.Types (Header, methodPost)
import Network.Wai (Application)
import Servant (serveWithContext)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)
import qualified User.Api as User
import User.Server (server)
import User.Store (newStore)

-- | テスト専用のRSA鍵ペアで、指定したテナントの署名済みトークンを
-- 組み立てる。
signToken :: JWK -> UTCTime -> Text -> IO ByteString
signToken jwk expiresAt tenantId = do
  Right token <- runJOSE (buildToken jwk expiresAt tenantId)
  pure (LBS.toStrict (encodeCompact token))

buildToken :: JWK -> UTCTime -> Text -> JOSE JWTError IO SignedJWT
buildToken jwk expiresAt tenantId = do
  alg <- bestJWSAlg jwk
  let claims = addClaim "tenant_id" (String tenantId)
             $ emptyClaimsSet
                 & claimSub ?~ "alice"
                 & claimExp ?~ NumericDate expiresAt
  signClaims jwk (newJWSHeaderProtected alg) claims

authHeader :: ByteString -> Header
authHeader token = ("Authorization", "Bearer " <> token)

mkTestApp :: JWK -> IO Application
mkTestApp jwk = do
  store <- newStore
  pure (serveWithContext (Proxy :: Proxy User.API) (authContext (mkJWKStore (JWKSet [jwk]))) (server store))

spec :: Spec
spec = do
  jwk <- runIO (genJWK (RSAGenParam (2048 `div` 8)))
  now <- runIO getCurrentTime
  acmeToken <- runIO (signToken jwk (addUTCTime 3600 now) "acme")
  globexToken <- runIO (signToken jwk (addUTCTime 3600 now) "globex")

  with (mkTestApp jwk) $ do
    describe "POST /users" $
      it "テナントacmeでユーザーを作成すると、201と作成したユーザーを返す" $
        request methodPost "/users" [authHeader acmeToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
          `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]
            { matchStatus = 201 }

    describe "GET /users（テナント分離）" $
      it "テナントacmeの一覧にテナントglobexのユーザーは含まれない" $ do
        _ <- request methodPost "/users" [authHeader acmeToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
        _ <- request methodPost "/users" [authHeader globexToken, ("Content-Type", "application/json")]
          "{\"name\":\"Bob\",\"email\":\"bob@example.com\"}"
        request "GET" "/users" [authHeader acmeToken] ""
          `shouldRespondWith` [json|[{id:1,name:"Alice",email:"alice@example.com"}]|]

    describe "GET /users/{id}（テナント分離）" $ do
      it "自テナントが作成したidは取得できる" $ do
        _ <- request methodPost "/users" [authHeader acmeToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
        request "GET" "/users/1" [authHeader acmeToken] ""
          `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]

      it "他テナントが作成したidは404になる" $ do
        _ <- request methodPost "/users" [authHeader acmeToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
        request "GET" "/users/1" [authHeader globexToken] "" `shouldRespondWith` 404

    describe "tenant_idクレームがないトークン" $
      it "401を返す" $ do
        Right tokenWithoutTenant <- liftIO $ runJOSE $ do
          alg <- bestJWSAlg jwk
          let claims = emptyClaimsSet
                & claimSub ?~ "alice"
                & claimExp ?~ NumericDate (addUTCTime 3600 now)
          signClaims jwk (newJWSHeaderProtected alg) claims :: JOSE JWTError IO SignedJWT
        request "GET" "/users" [authHeader (LBS.toStrict (encodeCompact tokenWithoutTenant))] ""
          `shouldRespondWith` 401
