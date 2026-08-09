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
-- ハンドラはもはや「データがどう保存されているか」を一切知らず、
-- AuthenticatedUserからテナントIDを取り出してUserRepositoryに委譲する
-- だけになっている（実際のCRUDロジックはUser.Repository.InMemory・
-- User.Repository.PostgresのTODOとして残っている）。
--
-- Iteration 5で、createUserHandlerにロールに基づく権限チェックと
-- メールアドレスの形式検証を追加する。認証（誰か）と認可（何をしてよい
-- か）は別の関心事であり、認証はAuthProtect "jwt"（Servantのルーティング
-- 解決の一部としてハンドラ本体より先に走る）が担うのに対し、認可は
-- ハンドラ本体のドメインロジックとして書く。
--
-- TODO: createUserHandlerを実装し、test/unit/User/UserSpec.hs・
-- test/integration/User/UserSpec.hsをGREENにすること。
-- ヒント：
-- - authRole authUserがAdminでなければUser.Error.Forbiddenを
--   User.Error.throwUserErrorで投げる。
-- - メールアドレスがisValidEmail（下に定義済み）を満たさなければ
--   User.Error.InvalidEmailをthrowUserErrorで投げる。
-- - どちらも満たせば、Iteration 4までと同じくliftIO (createUser repo
--   (authTenantId authUser) reqName reqEmail)でUserRepositoryに委譲する。
server :: UserRepository -> Server API
server repo = createUserHandler :<|> listUsersHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler _authUser _req = error "TODO: Iteration 5で実装する"

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
