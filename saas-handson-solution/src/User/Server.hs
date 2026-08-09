module User.Server
  ( Store
  , newStore
  , server
  ) where

import Auth.Types (AuthenticatedUser (authTenantId), TenantId)
import Control.Monad.IO.Class (liftIO)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Servant
import User.Api (API)
import User.Types (CreateUserRequest (..), User (..))

-- | in-memoryのユーザーストア。
--
-- テナントIDごとに(次に採番するid, 登録済みユーザー一覧)を保持する
-- IORef。テナントごとにMapのキーを分けることで、採番・一覧取得が
-- 常にテナント境界を越えないことを型・データ構造レベルで保証する
-- （あるテナントのユーザー一覧を取得するコードは、原理的に他テナントの
-- キーへアクセスしようがない）。ハンドラ間で共有するmutable stateであり、
-- atomicModifyIORef'で採番と登録を単一の原子的操作として行うことで、
-- 複数リクエストが同時に来ても採番id・一覧の破損を防ぐ。
type Store = IORef (Map TenantId (Int, [User]))

newStore :: IO Store
newStore = newIORef Map.empty

-- | Iteration 3で、AuthenticatedUserが持つauthTenantIdをStoreのキーに
-- 使うようになった。Iteration 2の時点では「認証済みであること」の確認
-- （＝Servantのroute解決がここまで到達していること自体）だけが目的
-- だったAuthenticatedUserが、ここで初めてドメインロジックの分岐条件
-- として使われる。
server :: Store -> Server API
server store = createUserHandler :<|> listUsersHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler authUser (CreateUserRequest reqName reqEmail) =
      liftIO $ atomicModifyIORef' store $ \tenants ->
        let tenantId = authTenantId authUser
            (nextId, users) = Map.findWithDefault (1, []) tenantId tenants
            newUser = User nextId reqName reqEmail
            tenants' = Map.insert tenantId (nextId + 1, users ++ [newUser]) tenants
        in (tenants', newUser)

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler authUser = liftIO $ do
      tenants <- readIORef store
      pure (maybe [] snd (Map.lookup (authTenantId authUser) tenants))
