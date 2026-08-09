{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}

module Auth.Types
  ( AuthenticatedUser (..)
  ) where

import Data.Text (Text)
import Servant.API.Experimental.Auth (AuthProtect)
import Servant.Server.Experimental.Auth (AuthServerData)

-- | JWT検証を通過したリクエストに紐づく「誰がアクセスしているか」の型。
--
-- 現時点ではJWTのsubクレームをそのまま保持するのみで、User機能の
-- ドメインとは接続していない。まずは「未認証のリクエストを拒否し、
-- 認証済みリクエストにはこの型の値が渡ってくる」という骨組みを作る。
newtype AuthenticatedUser = AuthenticatedUser
  { authSubject :: Text
  } deriving (Show, Eq)

-- | Servantの汎用認証コンビネータAuthProtectに、認証成功時に得られる
-- 値の型を結び付ける。この関連付けにより、
-- AuthProtect "jwt" :> API の型を持つエンドポイントのハンドラは
-- 自動的に AuthenticatedUser -> ... という関数として要求される。
type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser
