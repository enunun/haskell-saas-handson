module User.Server
  ( server
  ) where

import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Servant
import User.Api (API)
import User.Store (Store, createUser, getUser, listUsers)
import User.Types (CreateUserRequest (..), User)

-- | TODO: createUserHandler・listUsersHandler・getUserHandlerを実装し、
-- test/unit/User/UserSpec.hs・test/integration/User/UserSpec.hsを
-- GREENにすること。
-- ヒント：
-- - createUserHandlerは、User.Store.createUserにreqのcrName・crEmailを
--   渡してliftIOで実行するだけでよい。
-- - listUsersHandlerは、User.Store.listUsersをliftIOで実行するだけで
--   よい。
-- - getUserHandlerは、User.Store.getUserの結果（Maybe User）を見て、
--   Justならそのまま返し、Nothingならservant-serverのerr404を
--   throwError（Control.Monad.Except）で投げる。
server :: Store -> Server API
server store = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler :: CreateUserRequest -> Handler User
    createUserHandler _req = error "TODO: Iteration 1で実装する"

    listUsersHandler :: Handler [User]
    listUsersHandler = error "TODO: Iteration 1で実装する"

    getUserHandler :: Int -> Handler User
    getUserHandler _uid = error "TODO: Iteration 1で実装する"
