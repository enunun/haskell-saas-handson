module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
import Auth.Server (JWKStore, authContext)
import Servant
import qualified Health.Server as Health
import qualified User.Server as User
import User.Store (Store)

mkServer :: Store -> Server API
mkServer store = Health.server :<|> User.server store

-- | Iteration 2で`serve`を`serveWithContext`に変更した。User.APIの
-- `AuthProtect "jwt"`を解決するには`authContext`（AuthHandlerを含む
-- Context）をservantに渡す必要があるため。Healthは未認証のまま
-- （ヘルスチェックはロードバランサ等から認証なしで叩かれる前提）。
mkApp :: JWKStore -> Store -> Application
mkApp jwkStore store = serveWithContext api (authContext jwkStore) (mkServer store)
