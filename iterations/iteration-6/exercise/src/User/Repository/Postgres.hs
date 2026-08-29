{-# LANGUAGE OverloadedStrings #-}

module User.Repository.Postgres
  ( newPostgresUserRepository
  ) where

import Auth.Types (TenantId (..))
import Data.ByteString (ByteString)
import Data.Maybe (listToMaybe)
import Data.Pool (Pool, defaultPoolConfig, newPool, withResource)
import Data.Text (Text)
import Database.PostgreSQL.Simple
  ( Connection
  , Only (..)
  , close
  , connectPostgreSQL
  , query
  )
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import User.Repository (UserRepository (..))
import User.Types (User (..))

-- | usersテーブルの行をUserへ変換する。SELECTの列リスト（id, name,
-- email）とフィールドの並びが対応している必要がある。Userはpostgresql-
-- simpleを知らないUser.Typesに定義されているため、このインスタンスは
-- ここではorphan instanceになる。DB特有の変換ロジックをUser.Typesに
-- 持ち込みたくないため、意図的にここへ局所化している。
instance FromRow User where
  fromRow = User <$> field <*> field <*> field

-- | UserRepositoryのPostgreSQL実装。
--
-- connStrはlibpqのkeyword=value形式の接続文字列（例:
-- "host=db port=5432 dbname=saas_handson user=postgres
-- password=postgres"）。テーブルの作成・変更はこの関数の責務ではない。
-- スキーマは`db/schema.sql`とpsqldef（宣言的マイグレーションツール）で
-- 別途管理する。
--
-- postgresql-simpleのConnectionは複数スレッドから同時に使うことを
-- 想定していないため、resource-poolのPool Connectionを使い、
-- リクエストごとにプールからコネクションを借りて返す。
newPostgresUserRepository :: ByteString -> IO UserRepository
newPostgresUserRepository connStr = do
  pool <- newPool (defaultPoolConfig (connectPostgreSQL connStr) close 60 10)
  pure UserRepository
    { createUser = createUserImpl pool
    , listUsers = listUsersImpl pool
    , getUser = getUserImpl pool
    }

-- | idの採番はPostgreSQLのSERIAL（内部的には連番を払い出すシーケンス）
-- に完全に委ねている。INSERT ... RETURNING idは「採番」と「登録」を
-- 単一のSQL文で同時に行い、その原子性はPostgreSQLが保証する。
-- アプリケーション側でロック・トランザクションを意識するコードが
-- 一切不要になっている。
createUserImpl :: Pool Connection -> TenantId -> Text -> Text -> IO User
createUserImpl pool tenantId name email =
  withResource pool $ \conn -> do
    [Only newId] <- query conn
      "INSERT INTO users (tenant_id, name, email) VALUES (?, ?, ?) RETURNING id"
      (unTenantId tenantId, name, email)
    pure (User newId name email)

listUsersImpl :: Pool Connection -> TenantId -> IO [User]
listUsersImpl pool tenantId =
  withResource pool $ \conn ->
    query conn
      "SELECT id, name, email FROM users WHERE tenant_id = ? ORDER BY id"
      (Only (unTenantId tenantId))

-- | tenant_idとidの両方をWHERE句に含めることで、他テナントのidを
-- 指定した場合も「存在しない」場合と同じ0行になり、テナントの存在
-- 自体を漏らさない。
getUserImpl :: Pool Connection -> TenantId -> Int -> IO (Maybe User)
getUserImpl pool tenantId targetId =
  withResource pool $ \conn -> do
    rows <- query conn
      "SELECT id, name, email FROM users WHERE tenant_id = ? AND id = ?"
      (unTenantId tenantId, targetId)
    pure (listToMaybe rows)
