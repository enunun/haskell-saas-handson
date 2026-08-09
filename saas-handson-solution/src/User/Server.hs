module User.Server
  ( server
  ) where

import Auth.Types (AuthenticatedUser (authTenantId))
import Control.Monad.IO.Class (liftIO)
import Servant
import User.Api (API)
import User.Repository (UserRepository (..))
import User.Types (CreateUserRequest (..), User)

-- | Iteration 4で、Storeへの直接アクセスをUserRepository経由に置き換えた。
-- ハンドラはもはや「データがどう保存されているか」を一切知らず、
-- AuthenticatedUserからテナントIDを取り出してUserRepositoryに委譲する
-- だけになっている。
server :: UserRepository -> Server API
server repo = createUserHandler :<|> listUsersHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler authUser (CreateUserRequest reqName reqEmail) =
      liftIO (createUser repo (authTenantId authUser) reqName reqEmail)

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler authUser = liftIO (listUsers repo (authTenantId authUser))
