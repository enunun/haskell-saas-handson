{-# LANGUAGE OverloadedStrings #-}

module User.UserSpec (spec) where

import Servant (( :<|> ) (..))
import Servant.Server (runHandler)
import Test.Hspec
import User.Server (newStore, server)
import User.Types (CreateUserRequest (..), User (..))

-- | createUserHandler・listUsersHandlerの戻り値を直接検証する単体テスト。
spec :: Spec
spec = describe "User handlers（単体）" $ do
  it "createUserHandlerはid採番済みのUserを返す" $ do
    store <- newStore
    let create :<|> _list = server store
    Right created <- runHandler (create (CreateUserRequest "Alice" "alice@example.com"))
    created `shouldBe` User 1 "Alice" "alice@example.com"

  it "2件作成すると異なるidが採番される" $ do
    store <- newStore
    let create :<|> _list = server store
    Right u1 <- runHandler (create (CreateUserRequest "Alice" "alice@example.com"))
    Right u2 <- runHandler (create (CreateUserRequest "Bob" "bob@example.com"))
    userId u1 `shouldNotBe` userId u2

  it "listUsersHandlerは作成順に全件返す" $ do
    store <- newStore
    let create :<|> list = server store
    _ <- runHandler (create (CreateUserRequest "Alice" "alice@example.com"))
    _ <- runHandler (create (CreateUserRequest "Bob" "bob@example.com"))
    Right users <- runHandler list
    map userName users `shouldBe` ["Alice", "Bob"]
