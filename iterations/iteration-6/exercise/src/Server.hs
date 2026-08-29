module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
import Auth.Server (JWKStore, authContext)
import Servant
import qualified Health.Server as Health
import qualified User.Server as User
import User.Repository (UserRepository)

mkServer :: UserRepository -> Server API
mkServer repo = Health.server :<|> User.server repo

-- | Iteration 2で`serve`を`serveWithContext`に変更した。User.APIの
-- `AuthProtect "jwt"`を解決するには`authContext`（AuthHandlerを含む
-- Context）をservantに渡す必要があるため。Healthは未認証のまま
-- （ヘルスチェックはロードバランサ等から認証なしで叩かれる前提）。
mkApp :: JWKStore -> UserRepository -> Application
mkApp jwkStore repo = serveWithContext api (authContext jwkStore) (mkServer repo)
