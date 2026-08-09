{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Health.Api
  ( API
  ) where

import Health.Types (HealthResponse)
import Servant

-- | Health機能のAPI型。
--
-- Servantでは、エンドポイントの仕様を値ではなく型で表現する。
-- この型自体が仕様書であり、実装（Health.Server）はこの型を
-- 満たすことをコンパイラによって強制される。
type API = "health" :> Get '[JSON] HealthResponse
