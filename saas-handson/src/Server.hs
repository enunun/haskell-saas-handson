module Server
  ( app
  , server
  ) where

import Api (API, api)
import Servant
import Types (HealthResponse (..))

-- | APIハンドラの実装。
--
-- TODO: healthHandlerを実装し、test/HealthSpec.hsをGREENにすること。
-- ヒント：HealthResponseのstatusフィールドに"ok"を設定し、
-- Handlerモナドの中でpureを使って返す。
server :: Server API
server = healthHandler
  where
    healthHandler :: Handler HealthResponse
    healthHandler = error "TODO: Iteration 0で実装する"

-- | WAI Applicationへの変換。
--
-- servant-serverのserve関数が、API型とハンドラからWAI Applicationを
-- 生成する。この関数自体は変更不要である。
app :: Application
app = serve api server
