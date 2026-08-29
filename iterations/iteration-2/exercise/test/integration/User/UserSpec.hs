{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module User.UserSpec (spec) where

import Data.Proxy (Proxy (..))
import Network.Wai (Application)
import Network.HTTP.Types (methodPost)
import Servant (serve)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)
import qualified User.Api as User
import User.Server (server)
import User.Store (newStore)

mkTestApp :: IO Application
mkTestApp = do
  store <- newStore
  pure (serve (Proxy :: Proxy User.API) (server store))

spec :: Spec
spec = with mkTestApp $ do
  describe "POST /users" $
    it "ユーザーを作成し、201と作成したユーザーを返す" $
      request methodPost "/users" [("Content-Type", "application/json")]
        "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
        `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]
          { matchStatus = 201 }

  describe "GET /users" $
    it "作成済みユーザーの一覧を返す" $ do
      _ <- request methodPost "/users" [("Content-Type", "application/json")]
        "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
      get "/users" `shouldRespondWith` [json|[{id:1,name:"Alice",email:"alice@example.com"}]|]

  describe "GET /users/{id}" $ do
    it "存在するidのユーザーを返す" $ do
      _ <- request methodPost "/users" [("Content-Type", "application/json")]
        "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
      get "/users/1" `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]

    it "存在しないidに対して404を返す" $
      get "/users/999" `shouldRespondWith` 404
