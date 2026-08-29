{-# LANGUAGE OverloadedStrings #-}

module User.Server
  ( server
  , isValidEmail
  ) where

import Auth.Types (AuthenticatedUser (authRole, authSubject, authTenantId), Role (Admin), TenantId (unTenantId))
import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import qualified Data.Text as Text
import Logging (Logger, logInfo, logWarn)
import Servant
import User.Api (API)
import User.Error (UserError (Forbidden, InvalidEmail), throwUserError)
import User.Repository (UserRepository (..))
import User.Types (CreateUserRequest (..), User (..))

-- | Iteration 6で、Loggerを注入し「誰が・どのテナントとして・何をした
-- （できなかった）か」を構造化ログとして残すようにする。
server :: Logger -> UserRepository -> Server API
server logger repo = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler authUser req
      | authRole authUser /= Admin = do
          liftIO (logWarn logger "user_creation_forbidden"
            [ ("tenant_id", unTenantId (authTenantId authUser))
            , ("subject", authSubject authUser)
            ])
          throwUserError Forbidden
      | not (isValidEmail (crEmail req)) = do
          liftIO (logWarn logger "user_creation_invalid_email"
            [ ("tenant_id", unTenantId (authTenantId authUser))
            , ("subject", authSubject authUser)
            , ("email", crEmail req)
            ])
          throwUserError (InvalidEmail (crEmail req))
      | otherwise = do
          newUser <- liftIO (createUser repo (authTenantId authUser) (crName req) (crEmail req))
          liftIO (logInfo logger "user_created"
            [ ("tenant_id", unTenantId (authTenantId authUser))
            , ("subject", authSubject authUser)
            , ("user_id", Text.pack (show (userId newUser)))
            ])
          pure newUser

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
