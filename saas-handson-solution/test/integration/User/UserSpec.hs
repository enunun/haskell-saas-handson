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
  , addClaim
  , claimExp
  , claimSub
  , emptyClaimsSet
  , encodeCompact
  , signClaims
  )
import Data.Aeson (Value (String))
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Database.PostgreSQL.Simple (close, connectPostgreSQL, execute_)
import Logging.Capturing (newCapturingLogger)
import Network.HTTP.Types.Header (Header, hAuthorization)
import Server (mkApp)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)
import User.Repository.Postgres (newPostgresUserRepository)

-- | devcontainerのdocker composeで一緒に起動するdbサービスへの接続文字列。
testConnStr :: ByteString
testConnStr = "host=db port=5432 dbname=saas_handson user=postgres password=postgres"

-- | 各テストの前にusersテーブルを空にする。hspec-waiのwithは"IO
-- Application"アクションをテストケースごとに再評価するため、この
-- リセットをApplication構築の一部にしておけば、テストケースごとに
-- クリーンな状態から始められる（":memory:"のSQLiteやテストごとに作り
-- 直すIORefが自動的に持っていた性質を、実DBに対して明示的に再現して
-- いる）。
resetDb :: IO ()
resetDb = do
  conn <- connectPostgreSQL testConnStr
  _ <- execute_ conn "TRUNCATE TABLE users RESTART IDENTITY"
  close conn

-- | テスト専用のRSA鍵ペアで署名した有効なトークンを組み立てる。実サーバー
-- では外部の認証サーバー（mock-oauth2-server）が発行するが、結合テストは
-- 外部プロセスに依存させたくないため、テスト内で鍵生成・署名まで行う。
signTestToken :: JWK -> Text -> Text -> IO Text
signTestToken jwk tenantId role = do
  now <- getCurrentTime
  Right token <- runJOSE (buildToken jwk now tenantId role)
  pure (TE.decodeUtf8 (LBS.toStrict (encodeCompact token)))

-- | eの型（JWTError）をrunJOSEに伝えるため、型シグネチャを明示した
-- トップレベル関数として定義する（do記法の中に直接書くと曖昧になる）。
buildToken :: JWK -> UTCTime -> Text -> Text -> JOSE JWTError IO SignedJWT
buildToken jwk now tenantId role = do
  alg <- bestJWSAlg jwk
  let claims = addClaim "tenant_id" (String tenantId)
             $ addClaim "role" (String role)
             $ emptyClaimsSet
                 & claimSub ?~ "alice"
                 & claimExp ?~ NumericDate (addUTCTime 3600 now)
  signClaims jwk (newJWSHeaderProtected alg) claims

authHeader :: Text -> Header
authHeader token = (hAuthorization, "Bearer " <> TE.encodeUtf8 token)

spec :: Spec
spec = do
  jwk <- runIO (genJWK (RSAGenParam (2048 `div` 8)))
  token <- runIO (signTestToken jwk "acme" "admin")
  otherTenantToken <- runIO (signTestToken jwk "globex" "admin")
  memberToken <- runIO (signTestToken jwk "acme" "member")
  repo <- runIO (newPostgresUserRepository testConnStr)
  (logger, _getLogs) <- runIO newCapturingLogger
  let app = resetDb >> pure (mkApp (mkJWKStore (JWKSet [jwk])) logger repo)

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

  with app $ describe "POST /users, GET /users（テナント分離）" $
    it "別テナントのトークンでは他テナントが作成したユーザーが見えない" $ do
      _ <- request "POST" "/users" [("Content-Type", "application/json"), authHeader token]
        [json|{name:"Alice",email:"alice@example.com"}|]
      request "GET" "/users" [authHeader otherTenantToken] "" `shouldRespondWith` [json|[]|]

  with app $ describe "POST /users（権限・バリデーション）" $ do
    it "Memberロールのトークンでは403 Forbiddenが返る" $
      request "POST" "/users" [("Content-Type", "application/json"), authHeader memberToken]
        [json|{name:"Bob",email:"bob@example.com"}|]
        `shouldRespondWith` 403

    it "Memberロールのトークンでも GET /usersはできる" $
      request "GET" "/users" [authHeader memberToken] "" `shouldRespondWith` [json|[]|]

    it "不正な形式のメールアドレスでは400 Bad Requestが返る" $
      request "POST" "/users" [("Content-Type", "application/json"), authHeader token]
        [json|{name:"Bob",email:"not-an-email"}|]
        `shouldRespondWith` 400

  with app $ describe "GET /users/{id}" $ do
    it "作成済みユーザーをidで取得できる" $ do
      _ <- request "POST" "/users" [("Content-Type", "application/json"), authHeader token]
        [json|{name:"Alice",email:"alice@example.com"}|]
      request "GET" "/users/1" [authHeader token] ""
        `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]

    it "存在しないidを指定すると404が返る" $
      request "GET" "/users/999" [authHeader token] "" `shouldRespondWith` 404

    it "他テナントのトークンで作成済みユーザーのidを指定すると404が返る（テナント分離）" $ do
      _ <- request "POST" "/users" [("Content-Type", "application/json"), authHeader token]
        [json|{name:"Alice",email:"alice@example.com"}|]
      request "GET" "/users/1" [authHeader otherTenantToken] "" `shouldRespondWith` 404

    it "AuthorizationヘッダなしのGET /users/{id}は401を返す" $
      get "/users/1" `shouldRespondWith` 401
