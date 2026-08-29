module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
import Auth.Server (JWKStore, authContext)
import Logging (Logger)
import Servant
import qualified Health.Server as Health
import qualified User.Server as User
import User.Repository (UserRepository)

mkServer :: Logger -> UserRepository -> Server API
mkServer logger repo = Health.server :<|> User.server logger repo

mkApp :: JWKStore -> Logger -> UserRepository -> Application
mkApp jwkStore logger repo = serveWithContext api (authContext jwkStore) (mkServer logger repo)
