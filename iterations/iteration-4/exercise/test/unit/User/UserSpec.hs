{-# LANGUAGE OverloadedStrings #-}

module User.UserSpec (spec) where

import Auth.Types (AuthenticatedUser (..), TenantId (..))
import Servant ((:<|>) (..), err404)
import Servant.Server (runHandler)
import Test.Hspec
import User.Server (server)
import User.Store (newStore)
import User.Types (CreateUserRequest (..), User (..))

acme :: AuthenticatedUser
acme = AuthenticatedUser "alice" (TenantId "acme")

globex :: AuthenticatedUser
globex = AuthenticatedUser "bob" (TenantId "globex")

spec :: Spec
spec = describe "User（単体）" $ do
  it "POST /usersでユーザーを作成すると、id=1から採番される" $ do
    store <- newStore
    let createUserHandler :<|> _ :<|> _ = server store
    result <- runHandler (createUserHandler acme (CreateUserRequest "Alice" "alice@example.com"))
    result `shouldBe` Right (User 1 "Alice" "alice@example.com")

  it "同一テナント内で2人目に作成したユーザーはid=2になる" $ do
    store <- newStore
    let createUserHandler :<|> _ :<|> _ = server store
    _ <- runHandler (createUserHandler acme (CreateUserRequest "Alice" "alice@example.com"))
    result <- runHandler (createUserHandler acme (CreateUserRequest "Carol" "carol@example.com"))
    result `shouldBe` Right (User 2 "Carol" "carol@example.com")

  it "異なるテナントの1人目のユーザーもid=1になる（採番系列がテナントごとに独立）" $ do
    store <- newStore
    let createUserHandlerAcme :<|> _ :<|> _ = server store
    _ <- runHandler (createUserHandlerAcme acme (CreateUserRequest "Alice" "alice@example.com"))
    result <- runHandler (createUserHandlerAcme globex (CreateUserRequest "Bob" "bob@example.com"))
    result `shouldBe` Right (User 1 "Bob" "bob@example.com")

  it "GET /usersは自テナントのユーザーだけを返す" $ do
    store <- newStore
    let createUserHandler :<|> listUsersHandler :<|> _ = server store
    _ <- runHandler (createUserHandler acme (CreateUserRequest "Alice" "alice@example.com"))
    _ <- runHandler (createUserHandler globex (CreateUserRequest "Bob" "bob@example.com"))
    result <- runHandler (listUsersHandler acme)
    result `shouldBe` Right [User 1 "Alice" "alice@example.com"]

  it "GET /users/{id}は自テナントの該当するidのユーザーを返す" $ do
    store <- newStore
    let createUserHandler :<|> _ :<|> getUserHandler = server store
    _ <- runHandler (createUserHandler acme (CreateUserRequest "Alice" "alice@example.com"))
    result <- runHandler (getUserHandler acme 1)
    result `shouldBe` Right (User 1 "Alice" "alice@example.com")

  it "GET /users/{id}は存在しないidに対して404を返す" $ do
    store <- newStore
    let _ :<|> _ :<|> getUserHandler = server store
    result <- runHandler (getUserHandler acme 999)
    result `shouldBe` Left err404

  it "GET /users/{id}は他テナントが作成したidに対しても404を返す（テナント分離）" $ do
    store <- newStore
    let createUserHandler :<|> _ :<|> getUserHandler = server store
    _ <- runHandler (createUserHandler acme (CreateUserRequest "Alice" "alice@example.com"))
    result <- runHandler (getUserHandler globex 1)
    result `shouldBe` Left err404
