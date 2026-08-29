{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Auth.Server
  ( JWKStore
  , newJWKStore
  , mkJWKStore
  , authContext
  , verifyToken
  ) where

import Auth.Types (AuthenticatedUser (..))
import Control.Lens ((^?), _Just)
import Control.Monad.Except (ExceptT, runExceptT, throwError)
import Control.Monad.IO.Class (liftIO)
import Crypto.JWT
  ( ClaimsSet
  , JWKSet
  , JWTError (JWTClaimsSetDecodeError)
  , SignedJWT
  , claimSub
  , decodeCompact
  , defaultJWTValidationSettings
  , string
  , verifyJWT
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Network.HTTP.Simple
  ( getResponseBody
  , httpJSON
  , parseRequest
  , setRequestCheckStatus
  )
import Network.Wai (Request, requestHeaders)
import Servant (Context (..), Handler, err401, errBody)
import Servant.Server.Experimental.Auth (AuthHandler, mkAuthHandler)

-- | 外部認証サーバー（本教材ではmock-oauth2-server）が公開するJWKSetを
-- 起動時に一度だけ取得してキャッシュしたもの。
newtype JWKStore = JWKStore JWKSet

-- | JWKS URI（例: "http://mock-auth:8080/default/jwks"）からJWKSetを
-- 取得する。
newJWKStore :: String -> IO JWKStore
newJWKStore jwksUri = do
  req <- setRequestCheckStatus <$> parseRequest jwksUri
  JWKStore . getResponseBody <$> httpJSON req

-- | 既知のJWKSetから直接JWKStoreを作る。ネットワークアクセスを伴わない
-- ため、テストで固定の鍵ペアを注入するのに使う。
mkJWKStore :: JWKSet -> JWKStore
mkJWKStore = JWKStore

-- | AuthProtect "jwt"のためのServantコンテキスト。serveWithContextに
-- 渡すことで、"jwt"タグの付いたエンドポイントすべてにauthHandlerが
-- 適用されるようになる。
authContext :: JWKStore -> Context '[AuthHandler Request AuthenticatedUser]
authContext store = authHandler store :. EmptyContext

authHandler :: JWKStore -> AuthHandler Request AuthenticatedUser
authHandler store = mkAuthHandler check
  where
    check :: Request -> Handler AuthenticatedUser
    check req = case bearerToken req of
      Nothing -> throwError (err401 { errBody = "Authorizationヘッダに Bearer トークンが必要です" })
      Just token -> do
        result <- liftIO (verifyToken store token)
        either (const (throwError unauthorized)) pure result

    unauthorized = err401 { errBody = "トークンの検証に失敗しました" }

-- | "Authorization: Bearer <token>"ヘッダからトークン部分だけを取り出す。
bearerToken :: Request -> Maybe Text
bearerToken req = do
  raw <- lookup "Authorization" (requestHeaders req)
  rest <- BS.stripPrefix "Bearer " raw
  either (const Nothing) Just (TE.decodeUtf8' rest)

-- | JWTの署名をJWKSetで検証し、有効期限（exp）等のクレームを検証した
-- うえで、subクレームをAuthenticatedUserとして取り出す。署名不正・
-- 期限切れ・subクレーム欠落のいずれもJWTErrorとして失敗する。
--
-- HTTPのリクエスト表現から独立しているため、単体テストではHTTP層を
-- 経由せずこの関数を直接呼び出して検証できる。
verifyToken :: JWKStore -> Text -> IO (Either JWTError AuthenticatedUser)
verifyToken (JWKStore jwks) token = runExceptT (verify jwks token)

verify :: JWKSet -> Text -> ExceptT JWTError IO AuthenticatedUser
verify jwks token = do
  jwt <- decodeCompact (LBS.fromStrict (TE.encodeUtf8 token)) :: ExceptT JWTError IO SignedJWT
  claims <- verifyJWT (defaultJWTValidationSettings (const True)) jwks jwt :: ExceptT JWTError IO ClaimsSet
  case claims ^? claimSub . _Just . string of
    Just sub -> pure (AuthenticatedUser sub)
    Nothing  -> throwError (JWTClaimsSetDecodeError "subクレームがありません")
