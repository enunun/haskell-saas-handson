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
-- テーブルの作成・変更はこの関数の責務ではない。スキーマは
-- db/schema.sqlとpsqldef（宣言的マイグレーションツール）で別途管理する
-- （docs/iteration-4.mdを参照）。このテスト・アプリを実行する前に、
-- 一度psqldefでスキーマを適用しておく必要がある。
--
-- postgresql-simpleのConnectionは複数スレッドから同時に使うことを想定
-- していない。IORefやMVarでの手作業の直列化ではなく、resource-poolの
-- Pool Connectionを使い、リクエストごとにプールからコネクションを
-- 借りて返す方式にしている。
newPostgresUserRepository :: ByteString -> IO UserRepository
newPostgresUserRepository connStr = do
  pool <- newPool (defaultPoolConfig (connectPostgreSQL connStr) close 60 10)
  pure UserRepository
    { createUser = createUserImpl pool
    , listUsers = listUsersImpl pool
    }

-- | TODO: createUserImpl・listUsersImplを実装し、
-- test/integration/User/RepositorySpec.hsをGREENにすること（devcontainer
-- の"db"サービス起動が必要）。
-- ヒント：
-- - idの採番はPostgreSQLのSERIALに完全に委ねる。
--   "INSERT INTO users (tenant_id, name, email) VALUES (?, ?, ?) RETURNING
--   id"をqueryで実行すれば、採番と登録を単一のSQL文・単一のDB往復で
--   原子的に行える（SQLiteのIteration 4当初案のような、明示的な
--   トランザクション・ロック制御はここでは不要になる。「自動発番の責務を
--   DB側に寄せる」とはこういうことである）。
-- - 戻り値の[Only newId] <- query ... のように1行1列の結果を取り出し、
--   User newId reqName reqEmailを返す。
-- - listUsersImplは"SELECT id, name, email FROM users WHERE tenant_id = ?
--   ORDER BY id"をqueryで実行するだけでよい（FromRow Userインスタンスは
--   すでに用意されている）。
createUserImpl :: Pool Connection -> TenantId -> Text -> Text -> IO User
createUserImpl _pool _tenantId _reqName _reqEmail = error "TODO: Iteration 4で実装する"

listUsersImpl :: Pool Connection -> TenantId -> IO [User]
listUsersImpl _pool _tenantId = error "TODO: Iteration 4で実装する"
