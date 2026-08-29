{-# LANGUAGE OverloadedStrings #-}

module User.Server
  ( server
  , isValidEmail
  ) where

import Auth.Types (AuthenticatedUser (authRole, authTenantId), Role (Admin))
import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import qualified Data.Text as Text
import Servant
import User.Api (API)
import User.Error (UserError (Forbidden, InvalidEmail), throwUserError)
import User.Repository (UserRepository (..))
import User.Types (CreateUserRequest (..), User)

-- | Iteration 5で、createUserHandlerにロールに基づく権限チェックと
-- メールアドレスの形式検証を追加する。認証（誰か）はAuthProtect "jwt"
-- （ルーティング解決の一部としてハンドラ本体より先に走る）が担うのに
-- 対し、認可（何をしてよいか）はハンドラ本体のドメインロジックとして
-- 書く。
server :: UserRepository -> Server API
server repo = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler authUser req
      | authRole authUser /= Admin = throwUserError Forbidden
      | not (isValidEmail (crEmail req)) = throwUserError (InvalidEmail (crEmail req))
      | otherwise = liftIO (createUser repo (authTenantId authUser) (crName req) (crEmail req))

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler authUser = liftIO (listUsers repo (authTenantId authUser))

    getUserHandler :: AuthenticatedUser -> Int -> Handler User
    getUserHandler authUser uid = do
      maybeUser <- liftIO (getUser repo (authTenantId authUser) uid)
      case maybeUser of
        Just u  -> pure u
        Nothing -> throwError err404

-- | "local@domain"の形（@がちょうど1つ、両側が空でない）かどうかの
-- 簡易チェック。RFC 5322準拠の完全なメールアドレス検証は本教材の
-- スコープ外である。
isValidEmail :: Text.Text -> Bool
isValidEmail email = case Text.splitOn "@" email of
  [local, domain] -> not (Text.null local) && not (Text.null domain)
  _ -> False
