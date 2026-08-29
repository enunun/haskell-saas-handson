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
import Data.Aeson (Value (String))
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LBS
import Data.Proxy (Proxy (..))
import Data.Text (Text)
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Database.PostgreSQL.Simple (close, connectPostgreSQL, execute_)
import Network.HTTP.Types (Header, methodPost)
import Network.Wai (Application)
import Servant (serveWithContext)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)
import qualified User.Api as User
import Logging.Capturing (newCapturingLogger)
import User.Repository.Postgres (newPostgresUserRepository)
import User.Server (server)

-- | devcontainerのdocker composeで一緒に起動するdbサービスへの接続
-- 文字列（app/Main.hsと同じ）。
dbConnStr :: ByteString
dbConnStr = "host=db port=5432 dbname=saas_handson user=postgres password=postgres"

-- | テスト専用のRSA鍵ペアで、指定したテナント・ロールの署名済み
-- トークンを組み立てる。
signToken :: JWK -> UTCTime -> Text -> Text -> IO ByteString
signToken jwk expiresAt tenantId role = do
  Right token <- runJOSE (buildToken jwk expiresAt tenantId role)
  pure (LBS.toStrict (encodeCompact token))

buildToken :: JWK -> UTCTime -> Text -> Text -> JOSE JWTError IO SignedJWT
buildToken jwk expiresAt tenantId role = do
  alg <- bestJWSAlg jwk
  let claims = addClaim "tenant_id" (String tenantId)
             $ addClaim "role" (String role)
             $ emptyClaimsSet
                 & claimSub ?~ "alice"
                 & claimExp ?~ NumericDate expiresAt
  signClaims jwk (newJWSHeaderProtected alg) claims

authHeader :: ByteString -> Header
authHeader token = ("Authorization", "Bearer " <> token)

-- | 各テストの前にusersテーブルを空にし、SERIALの採番も1から
-- やり直す。
mkTestApp :: JWK -> IO Application
mkTestApp jwk = do
  conn <- connectPostgreSQL dbConnStr
  _ <- execute_ conn "TRUNCATE TABLE users RESTART IDENTITY"
  close conn
  repo <- newPostgresUserRepository dbConnStr
  (logger, _getLogs) <- newCapturingLogger
  pure (serveWithContext (Proxy :: Proxy User.API) (authContext (mkJWKStore (JWKSet [jwk]))) (server logger repo))

spec :: Spec
spec = do
  jwk <- runIO (genJWK (RSAGenParam (2048 `div` 8)))
  now <- runIO getCurrentTime
  acmeAdminToken <- runIO (signToken jwk (addUTCTime 3600 now) "acme" "admin")
  acmeMemberToken <- runIO (signToken jwk (addUTCTime 3600 now) "acme" "member")
  globexAdminToken <- runIO (signToken jwk (addUTCTime 3600 now) "globex" "admin")

  with (mkTestApp jwk) $ do
    describe "POST /users（権限）" $ do
      it "adminはユーザーを作成でき、201と作成したユーザーを返す" $
        request methodPost "/users" [authHeader acmeAdminToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
          `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]
            { matchStatus = 201 }

      it "memberは403で拒否される" $
        request methodPost "/users" [authHeader acmeMemberToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
          `shouldRespondWith` 403

      it "不正な形式のメールアドレスは400で拒否される" $
        request methodPost "/users" [authHeader acmeAdminToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"not-an-email\"}"
          `shouldRespondWith` 400

    describe "GET /users（テナント分離）" $
      it "テナントacmeの一覧にテナントglobexのユーザーは含まれない" $ do
        _ <- request methodPost "/users" [authHeader acmeAdminToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
        _ <- request methodPost "/users" [authHeader globexAdminToken, ("Content-Type", "application/json")]
          "{\"name\":\"Bob\",\"email\":\"bob@example.com\"}"
        request "GET" "/users" [authHeader acmeAdminToken] ""
          `shouldRespondWith` [json|[{id:1,name:"Alice",email:"alice@example.com"}]|]

    describe "GET /users/{id}（テナント分離）" $ do
      it "自テナントが作成したidは取得できる" $ do
        _ <- request methodPost "/users" [authHeader acmeAdminToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
        request "GET" "/users/1" [authHeader acmeAdminToken] ""
          `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]

      it "他テナントが作成したidは404になる" $ do
        _ <- request methodPost "/users" [authHeader acmeAdminToken, ("Content-Type", "application/json")]
          "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
        request "GET" "/users/1" [authHeader globexAdminToken] "" `shouldRespondWith` 404
