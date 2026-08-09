module User.Repository.InMemory
  ( newInMemoryUserRepository
  ) where

import Auth.Types (TenantId)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import User.Repository (UserRepository (..))
import User.Types (User (..))

-- | UserRepositoryのin-memory実装。DBを起動できない・起動したくない
-- 場面（単体テストなど）で使う。単体テストはこの実装だけを使い、
-- 実DB（PostgreSQL）には一切依存しない（User.Repository.Postgresを
-- 使うテストはtest/integration側に置く）。
--
-- idの採番は、Iteration 4でPostgreSQL実装がSERIAL（DB側の自動採番）に
-- 責務を委ねたことに合わせ、テナントを跨いだグローバルな連番にした
-- （Iteration 3までの「テナントごとに1から連番」ではない）。テナント間の
-- データ分離自体はテナントIDをキーにしたMapで引き続き保証している。
newInMemoryUserRepository :: IO UserRepository
newInMemoryUserRepository = do
  store <- newIORef (1, Map.empty)
  pure UserRepository
    { createUser = createUserImpl store
    , listUsers = listUsersImpl store
    }

createUserImpl :: IORef (Int, Map TenantId [User]) -> TenantId -> Text -> Text -> IO User
createUserImpl store tenantId reqName reqEmail =
  atomicModifyIORef' store $ \(nextId, tenants) ->
    let users = Map.findWithDefault [] tenantId tenants
        newUser = User nextId reqName reqEmail
        tenants' = Map.insert tenantId (users ++ [newUser]) tenants
    in ((nextId + 1, tenants'), newUser)

listUsersImpl :: IORef (Int, Map TenantId [User]) -> TenantId -> IO [User]
listUsersImpl store tenantId =
  Map.findWithDefault [] tenantId . snd <$> readIORef store
