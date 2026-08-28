{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Api
  ( API
  , api
  ) where

import Data.Proxy (Proxy (..))
import Servant
import Types (HealthResponse)

-- | アプリケーション全体のAPI型。
--
-- Servantでは、エンドポイントの仕様を値ではなく型で表現する。この型
-- 自体が仕様書であり、実装（Server.hs）はこの型を満たすことを
-- コンパイラによって強制される。
type API = "health" :> Get '[JSON] HealthResponse

api :: Proxy API
api = Proxy
