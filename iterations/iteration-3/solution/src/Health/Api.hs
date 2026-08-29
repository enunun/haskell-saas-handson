{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Health.Api
  ( API
  ) where

import Servant
import Health.Types (HealthResponse)

type API = "health" :> Get '[JSON] HealthResponse
