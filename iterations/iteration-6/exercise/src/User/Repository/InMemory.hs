module User.Repository.InMemory
  ( newInMemoryUserRepository
  ) where

import Auth.Types (TenantId)
import Data.IORef (atomicModifyIORef', newIORef, readIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import User.Repository (UserRepository (..))
import User.Types (User (..))

-- | UserRepositoryのin-memory実装。DBを起動できない・起動したくない
-- 場面（単体テストなど）で使う。単体テストはこの実装だけを使い、
-- 実DB（PostgreSQL）には一切依存しない。
newInMemoryUserRepository :: IO UserRepository
newInMemoryUserRepository = do
  ref <- newIORef Map.empty
  pure UserRepository
    { createUser = \tenantId name email ->
        atomicModifyIORef' ref $ \tenants ->
          let (nextId, users) = Map.findWithDefault (1, Map.empty) tenantId tenants
              newUser = User nextId name email
              tenants' = Map.insert tenantId (nextId + 1, Map.insert nextId newUser users) tenants
          in (tenants', newUser)
    , listUsers = \tenantId -> do
        tenants <- readIORef ref
        pure (Map.elems (snd (Map.findWithDefault (1, Map.empty) tenantId tenants)))
    , getUser = \tenantId uid -> do
        tenants <- readIORef ref
        pure (Map.lookup uid (snd (Map.findWithDefault (1, Map.empty) tenantId tenants)))
    }
