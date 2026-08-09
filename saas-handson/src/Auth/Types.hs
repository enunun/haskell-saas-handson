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
--
-- Ord導出は、User.Serverでテナントごとのデータを分離するために
-- Map TenantId (...) のキーとして使うために必要。
newtype TenantId = TenantId { unTenantId :: Text } deriving (Show, Eq, Ord)

-- | テナント内でのユーザーの役割。JWTのroleクレームから取り出す。
--
-- Iteration 5時点ではUser機能（POST /users）の権限判定にのみ使うが、
-- 将来的な権限拡張（例：3段階以上のロール、リソースごとの細かい権限）
-- の起点になる型でもある。
data Role = Admin | Member deriving (Show, Eq)

instance FromJSON Role where
  parseJSON = withText "Role" $ \t -> case t of
    "admin"  -> pure Admin
    "member" -> pure Member
    other    -> fail ("unknown role: " ++ show other)

-- | JWT検証を通過したリクエストに紐づく「誰が・どのテナントの・
-- どういう役割としてアクセスしているか」の型。
--
-- Iteration 2ではsubクレームのみを保持していたが、Iteration 3で
-- テナントIDを、Iteration 5でロールを追加した。User機能はこの
-- authTenantIdを使ってテナントごとにデータを分離し、authRoleを使って
-- 操作ごとの権限を判定する。
data AuthenticatedUser = AuthenticatedUser
  { authSubject  :: Text
  , authTenantId :: TenantId
  , authRole     :: Role
  } deriving (Show, Eq)

-- | Servantの汎用認証コンビネータAuthProtectに、認証成功時に得られる
-- 値の型を結び付ける。この関連付けにより、
-- AuthProtect "jwt" :> API の型を持つエンドポイントのハンドラは
-- 自動的に AuthenticatedUser -> ... という関数として要求される。
type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser
