module User.Server
  ( Store
  , newStore
  , server
  ) where

import Auth.Types (AuthenticatedUser, TenantId)
import Data.IORef (IORef, newIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Servant
import User.Api (API)
import User.Types (CreateUserRequest (..), User (..))

-- | in-memoryのユーザーストア。
--
-- Iteration 3で、テナントIDごとに(次に採番するid, 登録済みユーザー一覧)
-- を保持するMapに変更した（Iteration 1時点ではIORef (Int, [User])と
-- テナントの概念がなかった）。createUserHandler・listUsersHandlerを
-- 実装する際は、AuthenticatedUserのauthTenantIdをMapのキーとして使い、
-- 他テナントのバケットには一切アクセスしないようにすること。
type Store = IORef (Map TenantId (Int, [User]))

newStore :: IO Store
newStore = newIORef Map.empty

-- | TODO: createUserHandler・listUsersHandlerを実装し、
-- test/unit/User/UserSpec.hs, test/integration/User/UserSpec.hsをGREENにすること。
-- ヒント：
-- - Data.Map.Strict.findWithDefaultで、authTenantId authUserに対応する
--   (次に採番するid, 登録済みユーザー一覧)を取り出す（未登録のテナント
--   なら(1, [])を初期値として使う）。
-- - Data.IORef.atomicModifyIORef'でMap全体を読み・書きし、該当テナント
--   のバケットだけをData.Map.Strict.insertで更新する。
server :: Store -> Server API
server _store = createUserHandler :<|> listUsersHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler _authUser _req = error "TODO: Iteration 1/3で実装する"

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler _authUser = error "TODO: Iteration 1/3で実装する"
