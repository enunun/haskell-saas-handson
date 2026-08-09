{-# LANGUAGE OverloadedStrings #-}

module User.Server
  ( server
  , isValidEmail
  ) where

import Auth.Types (AuthenticatedUser (authRole, authTenantId), Role (Admin))
import Control.Monad.IO.Class (liftIO)
import qualified Data.Text as Text
import Servant
import User.Api (API)
import User.Error (UserError (Forbidden, InvalidEmail), throwUserError)
import User.Repository (UserRepository (..))
import User.Types (CreateUserRequest (..), User)

-- | Iteration 4で、Storeへの直接アクセスをUserRepository経由に置き換えた。
-- Iteration 5で、createUserHandlerにロールに基づく権限チェックと
-- メールアドレスの形式検証を追加した。認証（誰か）と認可（何をしてよい
-- か）は別の関心事であり、認証はAuthProtect "jwt"（Servantのルーティング
-- 解決の一部としてハンドラ本体より先に走る）が担うのに対し、認可は
-- ハンドラ本体のドメインロジックとして書く。
server :: UserRepository -> Server API
server repo = createUserHandler :<|> listUsersHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler authUser (CreateUserRequest reqName reqEmail)
      | authRole authUser /= Admin = throwUserError Forbidden
      | not (isValidEmail reqEmail) = throwUserError (InvalidEmail reqEmail)
      | otherwise =
          liftIO (createUser repo (authTenantId authUser) reqName reqEmail)

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler authUser = liftIO (listUsers repo (authTenantId authUser))

-- | "local@domain"の形（@がちょうど1つ、両側が空でない）かどうかの
-- 簡易チェック。RFC 5322準拠の完全なメールアドレス検証は本教材の
-- スコープ外（実務ではバリデーション用ライブラリを使うか、最終的には
-- 実際に確認メールを送って検証するのが現実的である）。
isValidEmail :: Text.Text -> Bool
isValidEmail email = case Text.splitOn "@" email of
  [local, domain] -> not (Text.null local) && not (Text.null domain)
  _ -> False
