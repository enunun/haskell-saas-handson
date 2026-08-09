module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
import Auth.Server (JWKStore, authContext)
import Servant
import Types (HealthResponse (..))
import qualified User.Server as User
import User.Repository (UserRepository)

-- | APIハンドラの実装。
--
-- TODO: healthHandlerを実装し、test/unit/HealthSpec.hs・
-- test/integration/HealthSpec.hsをGREENにすること。
-- ヒント：HealthResponseのstatusフィールドに"ok"を設定し、
-- Handlerモナドの中でpureを使って返す。
--
-- Healthハンドラは現状ここに残っている。リファクタ後はHealth.Server.server
-- をqualified importして使う形に変更すること（docs/iteration-1.mdを参照）。
-- Iteration 4でUserのデータアクセスがStore（IORef直接）から
-- UserRepository（Repository抽象化）に変わり、mkServer/mkAppは
-- UserRepositoryを引数に取るようになった。
mkServer :: UserRepository -> Server API
mkServer repo = healthHandler :<|> User.server repo
  where
    healthHandler :: Handler HealthResponse
    healthHandler = error "TODO: Iteration 0で実装する"

-- | Iteration 2でserveをserveWithContextに変更した。User.APIの
-- AuthProtect "jwt"を解決するにはauthContext（AuthHandlerを含む
-- Context）をservantに渡す必要があるため。Healthは未認証のまま
-- （ヘルスチェックはロードバランサ等から認証なしで叩かれる前提）。
mkApp :: JWKStore -> UserRepository -> Application
mkApp jwkStore repo = serveWithContext api (authContext jwkStore) (mkServer repo)
