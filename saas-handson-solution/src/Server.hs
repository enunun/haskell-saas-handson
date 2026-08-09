module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
import Auth.Server (JWKStore, authContext)
import Servant
import qualified Health.Server as Health
import qualified User.Server as User
import User.Server (Store)

-- | アプリケーション全体のハンドラ実装。
--
-- 機能ごとのserver値を:<|>で合成する。UserはIORefで状態を持つため、
-- mkServer/mkAppはStoreを引数に取る関数になっている
-- （Healthのみだった頃は引数なしの値server :: Server APIで済んでいた）。
mkServer :: Store -> Server API
mkServer store = Health.server :<|> User.server store

-- | Iteration 2でserveをserveWithContextに変更した。User.APIの
-- AuthProtect "jwt"を解決するにはauthContext（AuthHandlerを含む
-- Context）をservantに渡す必要があるため。Healthは未認証のまま
-- （ヘルスチェックはロードバランサ等から認証なしで叩かれる前提）。
mkApp :: JWKStore -> Store -> Application
mkApp jwkStore store = serveWithContext api (authContext jwkStore) (mkServer store)
