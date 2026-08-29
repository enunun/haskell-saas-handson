{-# LANGUAGE OverloadedStrings #-}

module User.Types
  ( User (..)
  , CreateUserRequest (..)
  ) where

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import Data.Text (Text)

-- | `User`と`CreateUserRequest`はどちらも「ユーザー名」を持つが、
-- Haskellのレコードフィールド名は同じモジュール内で一意である必要が
-- あるため、`userName`・`crName`のように名前をずらしている
-- （フィールドアクセサは`User -> Text`のような普通のトップレベル関数
-- として生成されるため、同名では衝突する）。
data User = User
  { userId    :: Int
  , userName  :: Text
  , userEmail :: Text
  } deriving (Show, Eq)

instance ToJSON User where
  toJSON u = object
    [ "id"    .= userId u
    , "name"  .= userName u
    , "email" .= userEmail u
    ]

instance FromJSON User where
  parseJSON = withObject "User" $ \v ->
    User <$> v .: "id" <*> v .: "name" <*> v .: "email"

data CreateUserRequest = CreateUserRequest
  { crName  :: Text
  , crEmail :: Text
  } deriving (Show, Eq)

instance FromJSON CreateUserRequest where
  parseJSON = withObject "CreateUserRequest" $ \v ->
    CreateUserRequest <$> v .: "name" <*> v .: "email"
