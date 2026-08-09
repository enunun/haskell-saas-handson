{-# LANGUAGE OverloadedStrings #-}

module Health.Server
  ( server
  ) where

import Health.Api (API)
import Health.Types (HealthResponse (..))
import Servant

-- | Health機能のハンドラ実装。
server :: Server API
server = healthHandler
  where
    healthHandler :: Handler HealthResponse
    healthHandler = pure (HealthResponse "ok")
