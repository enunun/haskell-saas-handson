{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module User.Api
  ( API
  ) where

import Servant
import User.Types (CreateUserRequest, User)

type API =
       "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> "users" :> Get '[JSON] [User]
  :<|> "users" :> Capture "id" Int :> Get '[JSON] User
