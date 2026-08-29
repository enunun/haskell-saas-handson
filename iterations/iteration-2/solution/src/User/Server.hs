module User.Server
  ( server
  ) where

import Auth.Types (AuthenticatedUser)
import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Servant
import User.Api (API)
import User.Store (Store, createUser, getUser, listUsers)
import User.Types (CreateUserRequest (..), User)

-- | 3つのハンドラすべてがAuthenticatedUserを最初の引数として受け取る
-- ようになった（AuthProtect "jwt"がAPI型の一番外側にあるため）。現時点
-- ではまだ「誰か」を判定材料には使わず、認証を通過したことだけを要求
-- する。テナントによるデータ分離（Iteration 3）・ロールによる権限判定
-- （Iteration 5）で、この引数を実際に使うようになる。
server :: Store -> Server API
server store = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler _authUser req = liftIO (createUser store (crName req) (crEmail req))

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler _authUser = liftIO (listUsers store)

    getUserHandler :: AuthenticatedUser -> Int -> Handler User
    getUserHandler _authUser uid = do
      maybeUser <- liftIO (getUser store uid)
      case maybeUser of
        Just u  -> pure u
        Nothing -> throwError err404
