{-# LANGUAGE OverloadedStrings #-}

module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
import Servant
import Types (HealthResponse (..))

-- | APIハンドラの実装。
mkServer :: Server API
mkServer = healthHandler
  where
    healthHandler :: Handler HealthResponse
    healthHandler = pure (HealthResponse "ok")

mkApp :: Application
mkApp = serve api mkServer
