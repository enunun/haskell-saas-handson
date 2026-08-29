{-# LANGUAGE OverloadedStrings #-}

module Health.Server
  ( server
  ) where

import Health.Api (API)
import Health.Types (HealthResponse (..))
import Servant

server :: Server API
server = healthHandler
  where
    healthHandler :: Handler HealthResponse
    healthHandler = pure (HealthResponse "ok")
