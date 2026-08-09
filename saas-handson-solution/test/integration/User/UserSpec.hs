{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module User.UserSpec (spec) where

import Auth.Server (mkJWKStore)
import Control.Lens ((&), (?~))
import Crypto.JOSE
  ( JOSE
  , JWK
  , KeyMaterialGenParam (RSAGenParam)
  , bestJWSAlg
  , genJWK
  , newJWSHeaderProtected
  , runJOSE
  )
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
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Network.HTTP.Types.Header (Header, hAuthorization)
import Server (mkApp)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)
import User.Server (newStore)

-- | テスト専用のRSA鍵ペアで署名した有効なトークンを組み立てる。実サーバー
-- では外部の認証サーバー（mock-oauth2-server）が発行するが、結合テストは
-- 外部プロセスに依存させたくないため、テスト内で鍵生成・署名まで行う。
signTestToken :: JWK -> IO Text
signTestToken jwk = do
  now <- getCurrentTime
  Right token <- runJOSE (buildToken jwk now)
  pure (TE.decodeUtf8 (LBS.toStrict (encodeCompact token)))

-- | eの型（JWTError）をrunJOSEに伝えるため、型シグネチャを明示した
-- トップレベル関数として定義する（do記法の中に直接書くと曖昧になる）。
buildToken :: JWK -> UTCTime -> JOSE JWTError IO SignedJWT
buildToken jwk now = do
  alg <- bestJWSAlg jwk
  let claims = emptyClaimsSet
        & claimSub ?~ "alice"
        & claimExp ?~ NumericDate (addUTCTime 3600 now)
  signClaims jwk (newJWSHeaderProtected alg) claims

authHeader :: Text -> Header
authHeader token = (hAuthorization, "Bearer " <> TE.encodeUtf8 token)

spec :: Spec
spec = do
  jwk <- runIO (genJWK (RSAGenParam (2048 `div` 8)))
  token <- runIO (signTestToken jwk)
  let app = mkApp (mkJWKStore (JWKSet [jwk])) <$> newStore

  with app $ describe "POST /users, GET /users（認証あり）" $ do
    it "POST /usersは201でid/name/emailを含むボディを返す" $
      request "POST" "/users" [("Content-Type", "application/json"), authHeader token]
          [json|{name:"Alice",email:"alice@example.com"}|]
        `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]
          { matchStatus = 201 }

    it "GET /usersは初期状態で空配列を返す" $
      request "GET" "/users" [authHeader token] "" `shouldRespondWith` [json|[]|]

    it "GET /usersは事前にPOSTしたユーザーを含む" $ do
      _ <- request "POST" "/users" [("Content-Type", "application/json"), authHeader token]
        [json|{name:"Alice",email:"alice@example.com"}|]
      request "GET" "/users" [authHeader token] ""
        `shouldRespondWith` [json|[{id:1,name:"Alice",email:"alice@example.com"}]|]

  with app $ describe "POST /users, GET /users（認証なし・不正トークン）" $ do
    it "AuthorizationヘッダなしのGET /usersは401を返す" $
      get "/users" `shouldRespondWith` 401

    it "不正なトークンでのGET /usersは401を返す" $
      request "GET" "/users" [authHeader "not-a-jwt"] "" `shouldRespondWith` 401
