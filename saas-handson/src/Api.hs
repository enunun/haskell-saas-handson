{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Api
  ( API
  , api
  ) where

import Data.Proxy (Proxy (..))
import Servant
import Types (HealthResponse)
import qualified User.Api as User

-- | アプリケーション全体のAPI型。
--
-- Servantでは、エンドポイントの仕様を値ではなく型で表現する。この型
-- 自体が仕様書であり、実装（Server.hs）はこの型を満たすことを
-- コンパイラによって強制される。
--
-- Healthは現在も技術層別構成（src/Api.hs, Server.hs, Types.hs）のまま
-- 残っている。Iteration 1ではまずこのHealthをsrc/Health/へリファクタ
-- リングし、User.Api.APIと同様にqualified importで組み合わせる形に
-- 揃えること（docs/iteration-1.mdを参照）。
type API = "health" :> Get '[JSON] HealthResponse :<|> User.API

api :: Proxy API
api = Proxy
