module User.Server
  ( server
  ) where

import Auth.Types (AuthenticatedUser (authTenantId))
import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Servant
import User.Api (API)
import User.Store (Store, createUser, getUser, listUsers)
import User.Types (CreateUserRequest (..), User)

-- | authTenantIdでUser.Storeに渡すことで、テナントごとにデータを
-- 分離する。あるテナントのユーザーが他テナントのデータへ到達する経路は
-- 存在しない（Storeが常にテナントIDでスコープされたデータしか返さない
-- ため）。
server :: Store -> Server API
server store = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler authUser req =
      liftIO (createUser store (authTenantId authUser) (crName req) (crEmail req))

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler authUser = liftIO (listUsers store (authTenantId authUser))

    -- | 存在しないid・他テナントのidは、いずれもStoreがNothingを返す
    -- ため区別せず404にする（「権限がない」と「存在しない」を区別しない
    -- ことで、他テナントのデータの存在自体を推測させない）。
    getUserHandler :: AuthenticatedUser -> Int -> Handler User
    getUserHandler authUser uid = do
      maybeUser <- liftIO (getUser store (authTenantId authUser) uid)
      case maybeUser of
        Just u  -> pure u
        Nothing -> throwError err404
