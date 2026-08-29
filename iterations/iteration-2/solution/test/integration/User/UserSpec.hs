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
  , claimExp
  , claimSub
  , emptyClaimsSet
  , encodeCompact
  , signClaims
  )
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LBS
import Data.Proxy (Proxy (..))
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

-- | テスト専用のRSA鍵ペアで署名した有効なトークンを組み立てる。
signToken :: JWK -> UTCTime -> IO ByteString
signToken jwk expiresAt = do
  Right token <- runJOSE (buildToken jwk expiresAt)
  pure (LBS.toStrict (encodeCompact token))

buildToken :: JWK -> UTCTime -> JOSE JWTError IO SignedJWT
buildToken jwk expiresAt = do
  alg <- bestJWSAlg jwk
  let claims = emptyClaimsSet
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
  validToken <- runIO (signToken jwk (addUTCTime 3600 now))

  with (mkTestApp jwk) $ do
    describe "認証" $ do
      it "Authorizationヘッダがないと401を返す" $
        get "/users" `shouldRespondWith` 401

      it "不正なトークンだと401を返す" $
        request "GET" "/users" [authHeader "not-a-jwt"] "" `shouldRespondWith` 401

    describe "POST /users" $
      it "有効なトークンがあればユーザーを作成し、201と作成したユーザーを返す" $
        request methodPost "/users" [authHeader validToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
          `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]
            { matchStatus = 201 }

    describe "GET /users" $
      it "有効なトークンがあれば作成済みユーザーの一覧を返す" $ do
        _ <- request methodPost "/users" [authHeader validToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
        request "GET" "/users" [authHeader validToken] ""
          `shouldRespondWith` [json|[{id:1,name:"Alice",email:"alice@example.com"}]|]

    describe "GET /users/{id}" $ do
      it "有効なトークンがあれば存在するidのユーザーを返す" $ do
        _ <- request methodPost "/users" [authHeader validToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
        request "GET" "/users/1" [authHeader validToken] ""
          `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]

      it "有効なトークンでも存在しないidには404を返す" $
        request "GET" "/users/999" [authHeader validToken] "" `shouldRespondWith` 404
