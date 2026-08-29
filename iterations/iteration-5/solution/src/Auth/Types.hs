{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Auth.Types
  ( AuthenticatedUser (..)
  , TenantId (..)
  , Role (..)
  ) where

import Data.Aeson (FromJSON (..), withText)
import Data.Text (Text)
import Servant.API.Experimental.Auth (AuthProtect)
import Servant.Server.Experimental.Auth (AuthServerData)

-- | 契約企業（テナント）を識別する型。JWTのtenant_idクレームから取り出す。
newtype TenantId = TenantId { unTenantId :: Text } deriving (Show, Eq, Ord)

-- | テナント内でのユーザーの役割。JWTのroleクレームから取り出す。
data Role = Admin | Member deriving (Show, Eq)

instance FromJSON Role where
  parseJSON = withText "Role" $ \t -> case t of
    "admin"  -> pure Admin
    "member" -> pure Member
    other    -> fail ("unknown role: " ++ show other)

-- | JWT検証を通過したリクエストに紐づく「誰が・どのテナントの・
-- どういう役割としてアクセスしているか」の型。
data AuthenticatedUser = AuthenticatedUser
  { authSubject  :: Text
  , authTenantId :: TenantId
  , authRole     :: Role
  } deriving (Show, Eq)

-- | Servantの汎用認証コンビネータAuthProtectに、認証成功時に得られる
-- 値の型を結び付ける。
type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser
