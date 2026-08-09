{-# LANGUAGE OverloadedStrings #-}

module Auth.AuthSpec (spec) where

import Auth.Server (mkJWKStore, verifyToken)
import Auth.Types (AuthenticatedUser (..))
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
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Test.Hspec

-- | テスト専用のRSA鍵ペアで署名した有効なトークンを組み立てる。
signToken :: JWK -> UTCTime -> IO Text
signToken jwk expiresAt = do
  Right token <- runJOSE (buildToken jwk expiresAt)
  pure (TE.decodeUtf8 (LBS.toStrict (encodeCompact token)))

-- | eの型（JWTError）をrunJOSEに伝えるため、型シグネチャを明示した
-- トップレベル関数として定義する（do記法の中に直接書くと曖昧になる）。
buildToken :: JWK -> UTCTime -> JOSE JWTError IO SignedJWT
buildToken jwk expiresAt = do
  alg <- bestJWSAlg jwk
  let claims = emptyClaimsSet
        & claimSub ?~ "alice"
        & claimExp ?~ NumericDate expiresAt
  signClaims jwk (newJWSHeaderProtected alg) claims

spec :: Spec
spec = describe "Auth.Server.verifyToken" $ do
  it "有効なトークンはsubクレームをAuthenticatedUserとして返す" $ do
    jwk <- genJWK (RSAGenParam (2048 `div` 8))
    now <- getCurrentTime
    token <- signToken jwk (addUTCTime 3600 now)
    result <- verifyToken (mkJWKStore (JWKSet [jwk])) token
    result `shouldBe` Right (AuthenticatedUser "alice")

  it "期限切れのトークンは拒否される" $ do
    jwk <- genJWK (RSAGenParam (2048 `div` 8))
    now <- getCurrentTime
    token <- signToken jwk (addUTCTime (-3600) now)
    result <- verifyToken (mkJWKStore (JWKSet [jwk])) token
    result `shouldSatisfy` isLeft

  it "登録されていない鍵で署名されたトークンは拒否される" $ do
    signingKey <- genJWK (RSAGenParam (2048 `div` 8))
    otherKey <- genJWK (RSAGenParam (2048 `div` 8))
    now <- getCurrentTime
    token <- signToken signingKey (addUTCTime 3600 now)
    result <- verifyToken (mkJWKStore (JWKSet [otherKey])) token
    result `shouldSatisfy` isLeft

  it "壊れたトークン文字列は拒否される" $ do
    jwk <- genJWK (RSAGenParam (2048 `div` 8))
    result <- verifyToken (mkJWKStore (JWKSet [jwk])) "not-a-jwt"
    result `shouldSatisfy` isLeft

isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft (Right _) = False
