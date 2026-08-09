{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module User.Api
  ( API
  ) where

import Servant
import Servant.API.Experimental.Auth (AuthProtect)
import User.Types (CreateUserRequest, User)

-- | User機能のAPI型。
--
-- POST /usersはIteration 1の時点ではバリデーション・重複チェックを
-- 行わない前提のため、成功時は常に201（PostCreated）を返す。
--
-- Iteration 2で両エンドポイントにAuthProtect "jwt"を追加し、認証を必須
-- にした。"jwt"というタグはAuth.Types.AuthServerData型族インスタンスと
-- Auth.Server.authContextを結び付けるための識別子である。
--
-- GET /users/{id}はCapture "id" Intでパスセグメントをidとして受け取り、
-- 単一のUserを返す。存在しないidを指定した場合は404を返す
-- （User.Server.getUserHandlerを参照）。
type API =
       AuthProtect "jwt" :> "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> AuthProtect "jwt" :> "users" :> Get '[JSON] [User]
  :<|> AuthProtect "jwt" :> "users" :> Capture "id" Int :> Get '[JSON] User
