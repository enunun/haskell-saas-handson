{-# LANGUAGE OverloadedStrings #-}

module User.UserSpec (spec) where

import Auth.Types (AuthenticatedUser (..))
import Servant ((:<|>) (..), err404)
import Servant.Server (runHandler)
import Test.Hspec
import User.Server (server)
import User.Store (newStore)
import User.Types (CreateUserRequest (..), User (..))

-- | 単体テストはUser.Server.serverを直接呼び出すため、JWT検証（Auth層）
-- を経由しない。認証を通過した後の`AuthenticatedUser`をそのまま
-- 渡せばよい。
testUser :: AuthenticatedUser
testUser = AuthenticatedUser "alice"

spec :: Spec
spec = describe "User（単体）" $ do
  it "POST /usersでユーザーを作成すると、id=1から採番される" $ do
    store <- newStore
    let createUserHandler :<|> _ :<|> _ = server store
    result <- runHandler (createUserHandler testUser (CreateUserRequest "Alice" "alice@example.com"))
    result `shouldBe` Right (User 1 "Alice" "alice@example.com")

  it "2人目に作成したユーザーはid=2になる" $ do
    store <- newStore
    let createUserHandler :<|> _ :<|> _ = server store
    _ <- runHandler (createUserHandler testUser (CreateUserRequest "Alice" "alice@example.com"))
    result <- runHandler (createUserHandler testUser (CreateUserRequest "Bob" "bob@example.com"))
    result `shouldBe` Right (User 2 "Bob" "bob@example.com")

  it "GET /usersは作成済みユーザーを一覧で返す" $ do
    store <- newStore
    let createUserHandler :<|> listUsersHandler :<|> _ = server store
    _ <- runHandler (createUserHandler testUser (CreateUserRequest "Alice" "alice@example.com"))
    result <- runHandler (listUsersHandler testUser)
    result `shouldBe` Right [User 1 "Alice" "alice@example.com"]

  it "GET /users/{id}は該当するidのユーザーを返す" $ do
    store <- newStore
    let createUserHandler :<|> _ :<|> getUserHandler = server store
    _ <- runHandler (createUserHandler testUser (CreateUserRequest "Alice" "alice@example.com"))
    result <- runHandler (getUserHandler testUser 1)
    result `shouldBe` Right (User 1 "Alice" "alice@example.com")

  it "GET /users/{id}は存在しないidに対して404を返す" $ do
    store <- newStore
    let _ :<|> _ :<|> getUserHandler = server store
    result <- runHandler (getUserHandler testUser 999)
    result `shouldBe` Left err404
