{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module User.Api
  ( API
  ) where

import Servant
import Servant.API.Experimental.Auth (AuthProtect)
import User.Types (CreateUserRequest, User)

type API =
       AuthProtect "jwt" :> "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> AuthProtect "jwt" :> "users" :> Get '[JSON] [User]
  :<|> AuthProtect "jwt" :> "users" :> Capture "id" Int :> Get '[JSON] User
