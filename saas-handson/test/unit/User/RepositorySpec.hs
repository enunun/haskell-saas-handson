{-# LANGUAGE OverloadedStrings #-}

module User.RepositorySpec (spec) where

import Auth.Types (TenantId (..))
import Test.Hspec
import User.Repository (UserRepository (..))
import User.Repository.InMemory (newInMemoryUserRepository)
import User.Types (User (..))

-- | UserRepositoryの「契約」（実装によらず満たすべき振る舞い）の単体テスト。
--
-- 単体テストは実DB（PostgreSQL）に一切依存せず、in-memory実装のみを
-- 検証する。同じ契約（repositoryContractSpec）をUser.Repository.Postgres
-- に対しても実行するテストはtest/integration/User/RepositorySpec.hsに
-- ある（dbサービスの起動を前提とするため、単体テストとは分離している）。
-- 2箇所のrepositoryContractSpecの実装は同一で、「同じ契約を異なる実装が
-- 満たしていること」を確認する契約テストになっている。
spec :: Spec
spec = describe "UserRepository（in-memory実装）" $
  repositoryContractSpec newInMemoryUserRepository

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

  it "採番はテナントを跨いでグローバルに行われる（DB側のSERIALに倣った挙動）" $ do
    repo <- newRepo
    acmeUser <- createUser repo (TenantId "acme") "Alice" "alice@example.com"
    globexUser <- createUser repo (TenantId "globex") "Bob" "bob@example.com"
    userId acmeUser `shouldBe` 1
    userId globexUser `shouldBe` 2
