module User.Repository.InMemory
  ( newInMemoryUserRepository
  ) where

import Auth.Types (TenantId)
import Data.IORef (atomicModifyIORef', newIORef, readIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import User.Repository (UserRepository (..))
import User.Types (User (..))

-- | TODO: UserRepositoryのin-memory実装を完成させ、
-- test/unit/User/UserSpec.hsをGREENにすること。
--
-- ヒント：`src/User/Store.hs`（Iteration 3で書いたテナントごとに
-- スコープしたIORef + Data.Map.Strict）とほぼ同じロジックを、
-- `UserRepository`というレコードの3つのフィールドとして組み立て
-- 直すだけでよい。`Store`という独自の型を作る必要はなく、`IORef`は
-- この関数のクロージャの中に閉じ込めてしまってよい。
newInMemoryUserRepository :: IO UserRepository
newInMemoryUserRepository = do
  ref <- newIORef (Map.empty :: Map TenantId (Int, Map Int User))
  pure UserRepository
    { createUser = \_tenantId _name _email -> error "TODO: Iteration 4で実装する"
    , listUsers = \_tenantId -> error "TODO: Iteration 4で実装する"
    , getUser = \_tenantId _uid -> error "TODO: Iteration 4で実装する"
    }
