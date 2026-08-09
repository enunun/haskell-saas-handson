{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module User.Api
  ( API
  ) where

import Servant
import User.Types (CreateUserRequest, User)

-- | User機能のAPI型。
--
-- POST /usersはIteration 1の時点ではバリデーション・重複チェックを
-- 行わない前提のため、成功時は常に201（PostCreated）を返す。
type API =
       "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> "users" :> Get '[JSON] [User]
