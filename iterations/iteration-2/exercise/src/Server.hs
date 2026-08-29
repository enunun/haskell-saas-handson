module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
import Servant
import qualified Health.Server as Health
import qualified User.Server as User
import User.Store (Store)

-- | 機能ごとのserver値を:<|>で合成する。
mkServer :: Store -> Server API
mkServer store = Health.server :<|> User.server store

mkApp :: Store -> Application
mkApp store = serve api (mkServer store)
