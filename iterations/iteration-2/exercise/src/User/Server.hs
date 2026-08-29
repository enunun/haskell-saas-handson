module User.Server
  ( server
  ) where

import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Servant
import User.Api (API)
import User.Store (Store, createUser, getUser, listUsers)
import User.Types (CreateUserRequest (..), User)

server :: Store -> Server API
server store = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler :: CreateUserRequest -> Handler User
    createUserHandler req = liftIO (createUser store (crName req) (crEmail req))

    listUsersHandler :: Handler [User]
    listUsersHandler = liftIO (listUsers store)

    -- | 存在しないidは404を返す。マルチテナント対応は後続のIterationで
    -- 扱う。
    getUserHandler :: Int -> Handler User
    getUserHandler uid = do
      maybeUser <- liftIO (getUser store uid)
      case maybeUser of
        Just u  -> pure u
        Nothing -> throwError err404
