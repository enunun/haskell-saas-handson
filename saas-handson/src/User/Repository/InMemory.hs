module User.Repository.InMemory
  ( newInMemoryUserRepository
  ) where

import Auth.Types (TenantId)
import Data.IORef (IORef, newIORef)
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
-- idの採番は、PostgreSQL実装がSERIAL（DB側の自動採番）に責務を委ねる
-- ことに合わせ、テナントを跨いだグローバルな連番にする（Iteration 3
-- までの「テナントごとに1から連番」ではない）。テナント間のデータ分離
-- 自体はテナントIDをキーにしたMapで引き続き保証する。
newInMemoryUserRepository :: IO UserRepository
newInMemoryUserRepository = do
  store <- newIORef (1, Map.empty)
  pure UserRepository
    { createUser = createUserImpl store
    , listUsers = listUsersImpl store
    }

-- | TODO: createUserImpl・listUsersImplを実装し、
-- test/unit/User/RepositorySpec.hsをGREENにすること。Iteration 1
-- （採番・登録）・Iteration 3（テナント分離）で扱ったロジックがここに
-- 集約されている。
-- ヒント：
-- - Data.Map.Strict.findWithDefault []で、tenantIdに対応する登録済み
--   ユーザー一覧を取り出す（未登録のテナントなら空リスト）。
-- - Data.IORef.atomicModifyIORef'で(次に採番するグローバルid, 全テナント
--   分のMap)を読み・書きし、該当テナントのバケットだけを
--   Data.Map.Strict.insertで更新する。idの採番はテナントに関係なく
--   常にグローバルなカウンタを1つ進める。
createUserImpl :: IORef (Int, Map TenantId [User]) -> TenantId -> Text -> Text -> IO User
createUserImpl _store _tenantId _reqName _reqEmail = error "TODO: Iteration 1/3/4で実装する"

listUsersImpl :: IORef (Int, Map TenantId [User]) -> TenantId -> IO [User]
listUsersImpl _store _tenantId = error "TODO: Iteration 1/3/4で実装する"
