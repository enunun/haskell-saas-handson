{-# LANGUAGE OverloadedStrings #-}

module User.Repository.Postgres
  ( newPostgresUserRepository
  ) where

import Auth.Types (TenantId (..))
import Data.ByteString (ByteString)
import Data.Pool (Pool, defaultPoolConfig, newPool, withResource)
import Data.Text (Text)
import Database.PostgreSQL.Simple
  ( Connection
  , Only (..)
  , close
  , connectPostgreSQL
  , execute_
  , query
  )
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import User.Repository (UserRepository (..))
import User.Types (User (..))

-- | usersテーブルの行をUserへ変換する。SELECTの列リスト（id, name,
-- email）とフィールドの並びが対応している必要がある。Userは
-- postgresql-simple（外部パッケージ）を知らないUser.Typesに定義されて
-- いるため、このインスタンスはここではorphan instanceになる。DB特有の
-- 変換ロジックをUser.Typesに持ち込みたくないため、意図的にここへ
-- 局所化している。
instance FromRow User where
  fromRow = User <$> field <*> field <*> field

-- | UserRepositoryのPostgreSQL実装。
--
-- connStrはlibpqのkeyword=value形式の接続文字列
-- （例: "host=db port=5432 dbname=saas_handson user=postgres
-- password=postgres"）。
--
-- postgresql-simpleのConnectionは（sqlite-simpleと同様）複数スレッドから
-- 同時に使うことを想定していない。IORefやMVarでの手作業の直列化ではなく、
-- resource-poolのPool Connectionを使い、リクエストごとにプールから
-- コネクションを借りて返す方式にした。Postgresサーバー自体は複数
-- コネクションからの同時アクセスを安全に処理できるため、Webサーバーの
-- 各リクエストスレッドが（プールが空いていれば）並行してDBにアクセス
-- できる。
newPostgresUserRepository :: ByteString -> IO UserRepository
newPostgresUserRepository connStr = do
  pool <- newPool (defaultPoolConfig (connectPostgreSQL connStr) close 60 10)
  withResource pool $ \conn -> do
    _ <- execute_ conn
      "CREATE TABLE IF NOT EXISTS users \
      \( id SERIAL PRIMARY KEY \
      \, tenant_id TEXT NOT NULL \
      \, name TEXT NOT NULL \
      \, email TEXT NOT NULL \
      \)"
    pure ()
  pure UserRepository
    { createUser = createUserImpl pool
    , listUsers = listUsersImpl pool
    }

-- | idの採番はPostgreSQLのSERIAL（内部的には連番を払い出すシーケンス）
-- に完全に委ねている。SQLiteでの実装（Iteration 4当初案）が
-- 「SELECT MAX(id)して+1し、競合しないようトランザクションで守る」と
-- いう手続きをアプリケーション側に書く必要があったのに対し、SERIAL＋
-- INSERT ... RETURNING idは単一のSQL文で「採番」と「登録」を同時に
-- 行い、その原子性はPostgreSQLが保証する。アプリケーション側で
-- ロック・トランザクションを意識するコードが一切不要になっている点が、
-- 「自動発番の責務をDB側に寄せる」ことの具体的な効果である。
createUserImpl :: Pool Connection -> TenantId -> Text -> Text -> IO User
createUserImpl pool tenantId reqName reqEmail =
  withResource pool $ \conn -> do
    [Only newId] <- query conn
      "INSERT INTO users (tenant_id, name, email) VALUES (?, ?, ?) RETURNING id"
      (unTenantId tenantId, reqName, reqEmail)
    pure (User newId reqName reqEmail)

listUsersImpl :: Pool Connection -> TenantId -> IO [User]
listUsersImpl pool tenantId =
  withResource pool $ \conn ->
    query conn
      "SELECT id, name, email FROM users WHERE tenant_id = ? ORDER BY id"
      (Only (unTenantId tenantId))
