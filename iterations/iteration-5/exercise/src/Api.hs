{-# LANGUAGE TypeOperators #-}

module Api
  ( API
  , api
  ) where

import Data.Proxy (Proxy (..))
import Servant
import qualified Health.Api as Health
import qualified User.Api as User

type API = Health.API :<|> User.API

api :: Proxy API
api = Proxy
