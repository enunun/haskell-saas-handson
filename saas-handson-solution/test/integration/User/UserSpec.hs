{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module User.UserSpec (spec) where

import Server (mkApp)
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON (json)
import User.Server (newStore)

spec :: Spec
spec = with (mkApp <$> newStore) $
  describe "POST /users, GET /users" $ do
    it "POST /usersは201でid/name/emailを含むボディを返す" $
      request "POST" "/users" [("Content-Type", "application/json")]
          [json|{name:"Alice",email:"alice@example.com"}|]
        `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]
          { matchStatus = 201 }

    it "GET /usersは初期状態で空配列を返す" $
      get "/users" `shouldRespondWith` [json|[]|]

    it "GET /usersは事前にPOSTしたユーザーを含む" $ do
      _ <- request "POST" "/users" [("Content-Type", "application/json")]
        [json|{name:"Alice",email:"alice@example.com"}|]
      get "/users" `shouldRespondWith` [json|[{id:1,name:"Alice",email:"alice@example.com"}]|]
