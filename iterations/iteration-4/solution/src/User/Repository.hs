module User.Repository
  ( UserRepository (..)
  ) where

import Auth.Types (TenantId)
import Data.Text (Text)
import User.Types (User)

-- | ユーザーの永続化方式を抽象化するインターフェース。
--
-- レコード・オブ・関数（Handleパターン）で表現する。型クラスにせず値
-- として持ち回ることで、実装をIOアクションの中で自由に組み立てられる
-- （例えばPostgreSQL用はコネクションプールをクロージャで閉じ込める）。
--
-- createUser・listUsers・getUserはいずれもTenantIdを最初の引数に取り、
-- 実装側がテナント境界を越えたデータへアクセスしないことを型シグネチャで
-- 示す（Iteration 3で確立した設計をそのまま踏襲している）。
data UserRepository = UserRepository
  { createUser :: TenantId -> Text -> Text -> IO User
  , listUsers  :: TenantId -> IO [User]
  , getUser    :: TenantId -> Int -> IO (Maybe User)
  }
