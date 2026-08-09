module User.Repository
  ( UserRepository (..)
  ) where

import Auth.Types (TenantId)
import Data.Text (Text)
import User.Types (User)

-- | ユーザーの永続化方式を抽象化するインターフェース。
--
-- レコード・オブ・関数（Handleパターン）で表現する。型クラスにせず値
-- として持ち回るのは、実装をIOアクションの中で自由に組み立てられる
-- （例えばSQLite用はDBコネクションをクロージャで閉じ込める）ことと、
-- 1つのアプリケーションの中で複数の実装を切り替える必要がない
-- （型クラスの多態性が本質的には要らない）ことによる。
--
-- createUser・listUsersはいずれもTenantIdを最初の引数に取り、実装側が
-- テナント境界を越えたデータへアクセスしないことを型シグネチャで示す
-- （Iteration 3で確立した「テナントIDを渡さずにデータへアクセスする
-- 経路を作れなくする」という設計をそのまま踏襲している）。
data UserRepository = UserRepository
  { createUser :: TenantId -> Text -> Text -> IO User
  , listUsers  :: TenantId -> IO [User]
  }
