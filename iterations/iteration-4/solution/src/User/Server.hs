module User.Server
  ( server
  ) where

import Auth.Types (AuthenticatedUser (authTenantId))
import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Servant
import User.Api (API)
import User.Repository (UserRepository (..))
import User.Types (CreateUserRequest (..), User)

-- | Iteration 4で、Storeへの直接アクセスをUserRepository経由に
-- 置き換えた。ハンドラはもはや「データがどう保存されているか」を
-- 一切知らず、authTenantIdを取り出してUserRepositoryに委譲するだけに
-- なっている（実際のCRUDロジックはUser.Repository.InMemory・
-- User.Repository.Postgresが持つ）。
server :: UserRepository -> Server API
server repo = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler authUser req =
      liftIO (createUser repo (authTenantId authUser) (crName req) (crEmail req))

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler authUser = liftIO (listUsers repo (authTenantId authUser))

    getUserHandler :: AuthenticatedUser -> Int -> Handler User
    getUserHandler authUser uid = do
      maybeUser <- liftIO (getUser repo (authTenantId authUser) uid)
      case maybeUser of
        Just u  -> pure u
        Nothing -> throwError err404
