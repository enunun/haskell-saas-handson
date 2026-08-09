{-# LANGUAGE OverloadedStrings #-}

module User.UserSpec (spec) where

import Auth.Types (AuthenticatedUser (..), Role (..), TenantId (..))
import Servant (( :<|> ) (..), ServerError (errHTTPCode))
import Servant.Server (runHandler)
import Test.Hspec
import User.Repository.InMemory (newInMemoryUserRepository)
import User.Server (server)
import User.Types (CreateUserRequest (..), User (..))

-- | createUserHandler・listUsersHandlerの戻り値を直接検証する単体テスト。
--
-- AuthProtect "jwt"の追加によりハンドラの第1引数にAuthenticatedUserが
-- 増えているが、単体テストはHTTP・JWT層を経由しないため、ダミーの
-- AuthenticatedUserをそのまま渡せばよい（JWT検証自体の単体テストは
-- Auth.AuthSpecが担う）。UserRepositoryはIteration 4でHandler本体から
-- 切り離されたため、ここではDBを起動せず高速なin-memory実装を使う
-- （in-memory実装・PostgreSQL実装が同じ契約を満たすことは
-- User.RepositorySpec〈単体・結合の両方〉が検証する）。
testUser :: AuthenticatedUser
testUser = AuthenticatedUser "test-user" (TenantId "acme") Admin

otherTenantUser :: AuthenticatedUser
otherTenantUser = AuthenticatedUser "other-user" (TenantId "globex") Admin

memberUser :: AuthenticatedUser
memberUser = AuthenticatedUser "member-user" (TenantId "acme") Member

spec :: Spec
spec = describe "User handlers（単体）" $ do
  it "createUserHandlerはid採番済みのUserを返す" $ do
    repo <- newInMemoryUserRepository
    let create :<|> _list = server repo
    Right created <- runHandler (create testUser (CreateUserRequest "Alice" "alice@example.com"))
    created `shouldBe` User 1 "Alice" "alice@example.com"

  it "2件作成すると異なるidが採番される" $ do
    repo <- newInMemoryUserRepository
    let create :<|> _list = server repo
    Right u1 <- runHandler (create testUser (CreateUserRequest "Alice" "alice@example.com"))
    Right u2 <- runHandler (create testUser (CreateUserRequest "Bob" "bob@example.com"))
    userId u1 `shouldNotBe` userId u2

  it "listUsersHandlerは作成順に全件返す" $ do
    repo <- newInMemoryUserRepository
    let create :<|> list = server repo
    _ <- runHandler (create testUser (CreateUserRequest "Alice" "alice@example.com"))
    _ <- runHandler (create testUser (CreateUserRequest "Bob" "bob@example.com"))
    Right users <- runHandler (list testUser)
    map userName users `shouldBe` ["Alice", "Bob"]

  it "別テナントのユーザーは互いに見えない（テナント分離）" $ do
    repo <- newInMemoryUserRepository
    let create :<|> list = server repo
    _ <- runHandler (create testUser (CreateUserRequest "Alice" "alice@example.com"))
    Right acmeUsers <- runHandler (list testUser)
    Right globexUsers <- runHandler (list otherTenantUser)
    map userName acmeUsers `shouldBe` ["Alice"]
    globexUsers `shouldBe` []

  it "採番はテナントを跨いでグローバルに行われる（DB側のSERIALに倣った挙動）" $ do
    repo <- newInMemoryUserRepository
    let create :<|> _list = server repo
    Right acmeUser <- runHandler (create testUser (CreateUserRequest "Alice" "alice@example.com"))
    Right globexUser <- runHandler (create otherTenantUser (CreateUserRequest "Bob" "bob@example.com"))
    userId acmeUser `shouldBe` 1
    userId globexUser `shouldBe` 2

  it "Memberロールのユーザーはcreateできない（403）" $ do
    repo <- newInMemoryUserRepository
    let create :<|> _list = server repo
    Left err <- runHandler (create memberUser (CreateUserRequest "Bob" "bob@example.com"))
    errHTTPCode err `shouldBe` 403

  it "Memberロールのユーザーでもlistはできる" $ do
    repo <- newInMemoryUserRepository
    let create :<|> list = server repo
    _ <- runHandler (create testUser (CreateUserRequest "Alice" "alice@example.com"))
    Right users <- runHandler (list memberUser)
    map userName users `shouldBe` ["Alice"]

  it "メールアドレスの形式が不正なリクエストは拒否される（400）" $ do
    repo <- newInMemoryUserRepository
    let create :<|> _list = server repo
    Left err <- runHandler (create testUser (CreateUserRequest "Alice" "not-an-email"))
    errHTTPCode err `shouldBe` 400
