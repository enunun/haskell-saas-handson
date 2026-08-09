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

-- | アプリケーション全体のハンドラ実装。
--
-- 機能ごとのserver値を:<|>で合成する。Iteration 4でUserのデータアクセス
-- がStore（IORef直接）からUserRepository（Repository抽象化）に変わり、
-- mkServer/mkAppはUserRepositoryを引数に取るようになった。Iteration 6で
-- Loggerも同様に引数として受け取り、User.serverへそのまま渡している。
mkServer :: Logger -> UserRepository -> Server API
mkServer logger repo = Health.server :<|> User.server logger repo

-- | Iteration 2でserveをserveWithContextに変更した。User.APIの
-- AuthProtect "jwt"を解決するにはauthContext（AuthHandlerを含む
-- Context）をservantに渡す必要があるため。Healthは未認証のまま
-- （ヘルスチェックはロードバランサ等から認証なしで叩かれる前提）。
mkApp :: JWKStore -> Logger -> UserRepository -> Application
mkApp jwkStore logger repo = serveWithContext api (authContext jwkStore) (mkServer logger repo)
