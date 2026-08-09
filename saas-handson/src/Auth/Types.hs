{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}

module Auth.Types
  ( AuthenticatedUser (..)
  , TenantId (..)
  ) where

import Data.Text (Text)
import Servant.API.Experimental.Auth (AuthProtect)
import Servant.Server.Experimental.Auth (AuthServerData)

-- | 契約企業（テナント）を識別する型。JWTのtenant_idクレームから取り出す。
--
-- Ord導出は、User.Serverでテナントごとのデータを分離するために
-- Map TenantId (...) のキーとして使うために必要。
newtype TenantId = TenantId { unTenantId :: Text } deriving (Show, Eq, Ord)

-- | JWT検証を通過したリクエストに紐づく「誰が・どのテナントとして
-- アクセスしているか」の型。
--
-- Iteration 2ではsubクレームのみを保持していたが、Iteration 3で
-- テナントIDを追加した。User機能はこのauthTenantIdを使ってテナント
-- ごとにデータを分離する。
data AuthenticatedUser = AuthenticatedUser
  { authSubject  :: Text
  , authTenantId :: TenantId
  } deriving (Show, Eq)

-- | Servantの汎用認証コンビネータAuthProtectに、認証成功時に得られる
-- 値の型を結び付ける。この関連付けにより、
-- AuthProtect "jwt" :> API の型を持つエンドポイントのハンドラは
-- 自動的に AuthenticatedUser -> ... という関数として要求される。
type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser
