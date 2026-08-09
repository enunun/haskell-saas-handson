module User.Server
  ( Store
  , newStore
  , server
  ) where

import Data.IORef (IORef, newIORef)
import Servant
import User.Api (API)
import User.Types (CreateUserRequest (..), User (..))

-- | in-memoryのユーザーストア。(次に採番するid, 登録済みユーザー一覧)を保持する。
type Store = IORef (Int, [User])

newStore :: IO Store
newStore = newIORef (1, [])

-- | TODO: createUserHandler・listUsersHandlerを実装し、
-- test/unit/User/UserSpec.hs, test/integration/User/UserSpec.hsをGREENにすること。
-- ヒント：Data.IORef.atomicModifyIORef'でカウンタとリストを同時に更新する。
server :: Store -> Server API
server _store = createUserHandler :<|> listUsersHandler
  where
    createUserHandler :: CreateUserRequest -> Handler User
    createUserHandler _req = error "TODO: Iteration 1で実装する"

    listUsersHandler :: Handler [User]
    listUsersHandler = error "TODO: Iteration 1で実装する"
