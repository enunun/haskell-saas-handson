module User.Server
  ( Store
  , newStore
  , server
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Servant
import User.Api (API)
import User.Types (CreateUserRequest (..), User (..))

-- | in-memoryのユーザーストア。
--
-- (次に採番するid, 登録済みユーザー一覧)を保持するIORef。
-- ハンドラ間で共有するmutable stateであり、atomicModifyIORef'で
-- 採番と登録を単一の原子的操作として行うことで、複数リクエストが
-- 同時に来ても採番id・一覧の破損を防ぐ。
type Store = IORef (Int, [User])

newStore :: IO Store
newStore = newIORef (1, [])

server :: Store -> Server API
server store = createUserHandler :<|> listUsersHandler
  where
    createUserHandler :: CreateUserRequest -> Handler User
    createUserHandler (CreateUserRequest reqName reqEmail) =
      liftIO $ atomicModifyIORef' store $ \(nextId, users) ->
        let newUser = User nextId reqName reqEmail
        in ((nextId + 1, users ++ [newUser]), newUser)

    listUsersHandler :: Handler [User]
    listUsersHandler = liftIO (snd <$> readIORef store)
