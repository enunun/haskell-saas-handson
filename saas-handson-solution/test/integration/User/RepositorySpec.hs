{-# LANGUAGE OverloadedStrings #-}

module User.RepositorySpec (spec) where

import Auth.Types (TenantId (..))
import Data.ByteString (ByteString)
import Database.PostgreSQL.Simple (close, connectPostgreSQL, execute_)
import Test.Hspec
import User.Repository (UserRepository (..))
import User.Repository.Postgres (newPostgresUserRepository)
import User.Types (User (..))

-- | devcontainerのdocker composeで一緒に起動するdbサービスへの接続文字列。
-- 単体テスト（test/unit）はこのサービスに依存しないが、結合テストは
-- 依存してよい、というのが本教材の方針である
-- （docs/iteration-4.mdを参照）。
testConnStr :: ByteString
testConnStr = "host=db port=5432 dbname=saas_handson user=postgres password=postgres"

-- | 各テストの前にusersテーブルを空にする。実DBはテストをまたいで状態が
-- 残り続けるため（":memory:"のSQLiteや、テストごとに作り直すIORefとは
-- 違い）、明示的なリセットが必要になる。RESTART IDENTITYでSERIALの
-- 採番も1から振り直し、テスト内のid採番アサーションを決定的にしている。
resetDb :: IO ()
resetDb = do
  conn <- connectPostgreSQL testConnStr
  _ <- execute_ conn "TRUNCATE TABLE users RESTART IDENTITY"
  close conn

-- | UserRepositoryの「契約」（実装によらず満たすべき振る舞い）を、実際の
-- PostgreSQLに対して検証する。テストの内容自体は
-- test/unit/User/RepositorySpec.hsのin-memory実装向けと完全に同一
-- （repositoryContractSpecという同じ形の関数を、newRepoの中身だけ
-- 差し替えて実行している）。これにより、「同じ契約を異なる実装が満たして
-- いる」ことをコードで保証している。
spec :: Spec
spec = describe "UserRepository（PostgreSQL実装, 実DB）" $
  repositoryContractSpec (resetDb >> newPostgresUserRepository testConnStr)

repositoryContractSpec :: IO UserRepository -> Spec
repositoryContractSpec newRepo = do
  it "createUserはid採番済みのUserを返す" $ do
    repo <- newRepo
    created <- createUser repo (TenantId "acme") "Alice" "alice@example.com"
    created `shouldBe` User 1 "Alice" "alice@example.com"

  it "同一テナントに2件作成すると連番でidが採番される" $ do
    repo <- newRepo
    u1 <- createUser repo (TenantId "acme") "Alice" "alice@example.com"
    u2 <- createUser repo (TenantId "acme") "Bob" "bob@example.com"
    userId u1 `shouldBe` 1
    userId u2 `shouldBe` 2

  it "listUsersは未登録のテナントに対して空リストを返す" $ do
    repo <- newRepo
    users <- listUsers repo (TenantId "acme")
    users `shouldBe` []

  it "listUsersは作成順に全件返す" $ do
    repo <- newRepo
    _ <- createUser repo (TenantId "acme") "Alice" "alice@example.com"
    _ <- createUser repo (TenantId "acme") "Bob" "bob@example.com"
    users <- listUsers repo (TenantId "acme")
    map userName users `shouldBe` ["Alice", "Bob"]

  it "別テナントのユーザーは互いに見えない（テナント分離）" $ do
    repo <- newRepo
    _ <- createUser repo (TenantId "acme") "Alice" "alice@example.com"
    acmeUsers <- listUsers repo (TenantId "acme")
    globexUsers <- listUsers repo (TenantId "globex")
    map userName acmeUsers `shouldBe` ["Alice"]
    globexUsers `shouldBe` []

  it "採番はテナントを跨いでグローバルに行われる（PostgreSQLのSERIAL由来）" $ do
    repo <- newRepo
    acmeUser <- createUser repo (TenantId "acme") "Alice" "alice@example.com"
    globexUser <- createUser repo (TenantId "globex") "Bob" "bob@example.com"
    userId acmeUser `shouldBe` 1
    userId globexUser `shouldBe` 2
