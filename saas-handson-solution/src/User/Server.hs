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

-- | Iteration 4で、Storeへの直接アクセスをUserRepository経由に置き換えた。
-- Iteration 5で、createUserHandlerにロールに基づく権限チェックと
-- メールアドレスの形式検証を追加した。認証（誰か）と認可（何をしてよい
-- か）は別の関心事であり、認証はAuthProtect "jwt"（Servantのルーティング
-- 解決の一部としてハンドラ本体より先に走る）が担うのに対し、認可は
-- ハンドラ本体のドメインロジックとして書く。
--
-- Iteration 6で、Loggerを注入し「誰が・どのテナントとして・何をした
-- （できなかった）か」を構造化ログとして残すようにした。UserRepository
-- と同じくHandleパターンで注入しているため、単体テストでは
-- Logging.Capturing（メモリ上に溜めるだけの実装）を使い、実際に標準
-- 出力へ書き込むことなくログ内容を検証できる。
server :: Logger -> UserRepository -> Server API
server logger repo = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler authUser (CreateUserRequest reqName reqEmail)
      | authRole authUser /= Admin = do
          liftIO $ logWarn logger "user_creation_forbidden"
            [ ("tenant_id", unTenantId (authTenantId authUser))
            , ("subject", authSubject authUser)
            ]
          throwUserError Forbidden
      | not (isValidEmail reqEmail) = do
          liftIO $ logWarn logger "user_creation_invalid_email"
            [ ("tenant_id", unTenantId (authTenantId authUser))
            , ("subject", authSubject authUser)
            , ("email", reqEmail)
            ]
          throwUserError (InvalidEmail reqEmail)
      | otherwise = do
          newUser <- liftIO (createUser repo (authTenantId authUser) reqName reqEmail)
          liftIO $ logInfo logger "user_created"
            [ ("tenant_id", unTenantId (authTenantId authUser))
            , ("subject", authSubject authUser)
            , ("user_id", Text.pack (show (userId newUser)))
            ]
          pure newUser

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler authUser = liftIO (listUsers repo (authTenantId authUser))

    -- | 見つからなければ404を返す。「権限がない」（Forbidden、Iteration 5）
    -- とは異なり、「リソースがそもそも存在しない」という単純な話なので
    -- UserErrorのドメインエラー機構は使わず、Servant.err404を直接投げる。
    getUserHandler :: AuthenticatedUser -> Int -> Handler User
    getUserHandler authUser targetId = do
      maybeUser <- liftIO (getUser repo (authTenantId authUser) targetId)
      case maybeUser of
        Just foundUser -> pure foundUser
        Nothing        -> throwError err404

-- | "local@domain"の形（@がちょうど1つ、両側が空でない）かどうかの
-- 簡易チェック。RFC 5322準拠の完全なメールアドレス検証は本教材の
-- スコープ外（実務ではバリデーション用ライブラリを使うか、最終的には
-- 実際に確認メールを送って検証するのが現実的である）。
isValidEmail :: Text.Text -> Bool
isValidEmail email = case Text.splitOn "@" email of
  [local, domain] -> not (Text.null local) && not (Text.null domain)
  _ -> False
