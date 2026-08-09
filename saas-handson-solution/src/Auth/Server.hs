{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Auth.Server
  ( JWKStore
  , newJWKStore
  , mkJWKStore
  , authContext
  , verifyToken
  ) where

import Auth.Types (AuthenticatedUser (..), Role, TenantId (..))
import Control.Lens ((^?), _Just)
import Control.Monad.Except (ExceptT, runExceptT, throwError)
import Control.Monad.IO.Class (liftIO)
import Crypto.JWT
  ( ClaimsSet
  , HasClaimsSet (..)
  , JWKSet
  , JWTError (JWTClaimsSetDecodeError)
  , SignedJWT
  , claimSub
  , decodeCompact
  , defaultJWTValidationSettings
  , string
  , verifyJWT
  )
import Data.Aeson (FromJSON (..), Value (Object), withObject, (.:))
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
-- 起動時に一度だけ取得してキャッシュしたもの。JWKSは複数の鍵を含みうる
-- ため、jose（Crypto.JWT.verifyClaims）は含まれる鍵を順に試して署名検証
-- する。鍵のローテーション（再取得）はこの教材のスコープ外とする。
newtype JWKStore = JWKStore JWKSet

-- | JWKS URI（例: "http://localhost:8081/default/jwks"）からJWKSetを
-- 取得する。本来はOIDCのdiscoveryドキュメント
-- （/.well-known/openid-configuration）のjwks_uriフィールドを経由するのが
-- 一般的だが、本教材では簡略化のためJWKS URIを直接与える。
newJWKStore :: String -> IO JWKStore
newJWKStore jwksUri = do
  req <- setRequestCheckStatus <$> parseRequest jwksUri
  JWKStore . getResponseBody <$> httpJSON req

-- | 既知のJWKSetから直接JWKStoreを作る。ネットワークアクセスを伴わない
-- ため、テストで固定の鍵ペアを注入するのに使う。
mkJWKStore :: JWKSet -> JWKStore
mkJWKStore = JWKStore

-- | AuthProtect "jwt"のためのServantコンテキスト。servantServeWithContext
-- に渡すことで、"jwt"タグの付いたエンドポイントすべてにauthHandlerが
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

-- | JWTの署名をJWKSetで検証し、有効期限（exp）等のクレームを検証したうえ
-- で、sub・tenant_id・roleクレームをAuthenticatedUserとして取り出す。
-- 署名不正・期限切れ・sub/tenant_id/roleクレーム欠落や不正な値の
-- いずれもJWTErrorとして失敗する。
--
-- HTTPのリクエスト表現から独立しているため、単体テストではHTTP層を
-- 経由せずこの関数を直接呼び出して検証できる。
verifyToken :: JWKStore -> Text -> IO (Either JWTError AuthenticatedUser)
verifyToken (JWKStore jwks) token = runExceptT (verify jwks token)

verify :: JWKSet -> Text -> ExceptT JWTError IO AuthenticatedUser
verify jwks token = do
  jwt <- decodeCompact (LBS.fromStrict (TE.encodeUtf8 token)) :: ExceptT JWTError IO SignedJWT
  claims <- verifyJWT (defaultJWTValidationSettings (const True)) jwks jwt :: ExceptT JWTError IO AuthClaims
  case subjectOf (authClaimsSet claims) of
    Just sub -> pure (AuthenticatedUser sub (TenantId (authClaimsTenantId claims)) (authClaimsRole claims))
    Nothing -> throwError (JWTClaimsSetDecodeError "subクレームがありません")

subjectOf :: ClaimsSet -> Maybe Text
subjectOf claims = claims ^? claimSub . _Just . string

-- | 標準のClaimsSet（RFC 7519で定義されたsub・exp等）に、非標準クレーム
-- であるtenant_id・roleを追加したサブタイプ。jose（Crypto.JWT）は追加
-- クレームを扱う場合、ClaimsSetをラップした独自の型にHasClaimsSet・
-- FromJSONインスタンスを与えることを推奨している（unregisteredClaimsは
-- 非推奨）。verifyJWTはこの型を検証対象のペイロードとして受け取る。
-- roleクレームのパースにはAuth.TypesのFromJSON Roleインスタンスを使う
-- ため、値が"admin"・"member"以外であればここで（＝JWT全体の検証結果
-- として）失敗する。
data AuthClaims = AuthClaims
  { authClaimsSet      :: ClaimsSet
  , authClaimsTenantId :: Text
  , authClaimsRole     :: Role
  }

instance HasClaimsSet AuthClaims where
  claimsSet f s = fmap (\a' -> s { authClaimsSet = a' }) (f (authClaimsSet s))

instance FromJSON AuthClaims where
  parseJSON = withObject "AuthClaims" $ \o ->
    AuthClaims <$> parseJSON (Object o) <*> o .: "tenant_id" <*> o .: "role"
