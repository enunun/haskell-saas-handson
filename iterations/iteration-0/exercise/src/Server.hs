module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
import Servant
import Types (HealthResponse (..))

-- | APIハンドラの実装。
--
-- TODO: healthHandlerを実装し、test/unit/HealthSpec.hs・
-- test/integration/HealthSpec.hsをGREENにすること。
-- ヒント：HealthResponseのstatusフィールドに"ok"を設定し、
-- Handlerモナドの中でpureを使って返す。
mkServer :: Server API
mkServer = healthHandler
  where
    healthHandler :: Handler HealthResponse
    healthHandler = error "TODO: Iteration 0で実装する"

mkApp :: Application
mkApp = serve api mkServer
