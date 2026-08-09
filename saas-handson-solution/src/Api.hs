module Api
  ( API
  , api
  ) where

import Data.Proxy (Proxy (..))
import Servant.API
import Types (HealthResponse)

-- | アプリケーション全体のAPI型。
--
-- Servantでは、ルーティング・HTTPメソッド・入出力の型がすべて
-- 型レベルで表現される。この型自体が仕様書であり、実装（Server.hs）は
-- この型を満たすことをコンパイラによって強制される。
type API = "health" :> Get '[JSON] HealthResponse

api :: Proxy API
api = Proxy
