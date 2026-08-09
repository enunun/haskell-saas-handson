module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
import Servant
import Types (HealthResponse (..))
import qualified User.Server as User
import User.Server (Store)

-- | APIハンドラの実装。
--
-- TODO: healthHandlerを実装し、test/unit/HealthSpec.hs・
-- test/integration/HealthSpec.hsをGREENにすること。
-- ヒント：HealthResponseのstatusフィールドに"ok"を設定し、
-- Handlerモナドの中でpureを使って返す。
--
-- Healthハンドラは現状ここに残っている。リファクタ後はHealth.Server.server
-- をqualified importして使う形に変更すること（docs/iteration-1.mdを参照）。
-- UserはIORefで状態を持つため、mkServer/mkAppはStoreを引数に取る関数に
-- なっている。
mkServer :: Store -> Server API
mkServer store = healthHandler :<|> User.server store
  where
    healthHandler :: Handler HealthResponse
    healthHandler = error "TODO: Iteration 0で実装する"

mkApp :: Store -> Application
mkApp store = serve api (mkServer store)
