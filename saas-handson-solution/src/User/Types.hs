{-# LANGUAGE OverloadedStrings #-}

module User.Types
  ( User (..)
  , CreateUserRequest (..)
  ) where

import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , object
  , withObject
  , (.:)
  , (.=)
  )
import Data.Text (Text)

-- | 登録済みユーザーのレスポンス表現。
--
-- レコードフィールド名は同一モジュール内のCreateUserRequestと衝突しない
-- よう userId/userName/userEmail とする（また"id"はPrelude.idと衝突する
-- ため避ける）。JSONへは手書きのToJSON/FromJSONインスタンスで
-- id/name/emailというクリーンなキー名にマッピングする。
data User = User
  { userId    :: Int
  , userName  :: Text
  , userEmail :: Text
  } deriving (Show, Eq)

instance ToJSON User where
  toJSON (User uid uname uemail) =
    object ["id" .= uid, "name" .= uname, "email" .= uemail]

instance FromJSON User where
  parseJSON = withObject "User" $ \v ->
    User <$> v .: "id" <*> v .: "name" <*> v .: "email"

-- | ユーザー登録リクエスト（POST /usersのボディ）。
--
-- Userと同じモジュール内でname/emailというフィールド名を再利用すると
-- レコードフィールド名が衝突するため、Haskell側のフィールド名はずらし
-- （crName/crEmail）、FromJSONインスタンスを手書きしてJSONキーは
-- Userと同じname/emailのまま受け付ける。Genericによる自動導出との
-- 対比はdocs/iteration-1.mdで解説する。
data CreateUserRequest = CreateUserRequest
  { crName  :: Text
  , crEmail :: Text
  } deriving (Show, Eq)

instance FromJSON CreateUserRequest where
  parseJSON = withObject "CreateUserRequest" $ \v ->
    CreateUserRequest <$> v .: "name" <*> v .: "email"
