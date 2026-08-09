{-# LANGUAGE TypeOperators #-}

module Api
  ( API
  , api
  ) where

import Data.Proxy (Proxy (..))
import Servant
import qualified Health.Api as Health
import qualified User.Api as User

-- | アプリケーション全体のAPI型。
--
-- 機能ごと（Health, User, ...）に定義されたAPI型を:<|>で合成する。
-- 機能が増えるたびにこの1行を足すだけでよく、各機能のルーティング定義
-- 自体はHealth.Api・User.Apiにカプセル化されたままである。
type API = Health.API :<|> User.API

api :: Proxy API
api = Proxy
