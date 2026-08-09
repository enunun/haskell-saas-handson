module Server
  ( mkApp
  , mkServer
  ) where

import Api (API, api)
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

mkApp :: Store -> Application
mkApp store = serve api (mkServer store)
