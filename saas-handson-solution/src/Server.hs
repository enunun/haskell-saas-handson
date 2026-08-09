module Server
  ( app
  , server
  ) where

import Api (API, api)
import Servant
import Types (HealthResponse (..))

-- | APIハンドラの実装。
--
-- 各エンドポイントに対応する処理を1つの値として合成する。
-- server の型は API 型から自動的に導出され、両者が一致しない場合は
-- コンパイルエラーとなる。
server :: Server API
server = healthHandler
  where
    healthHandler :: Handler HealthResponse
    healthHandler = pure (HealthResponse "ok")

-- | WAI Applicationへの変換。
--
-- servant-serverのserve関数が、API型とハンドラからWAI Applicationを
-- 生成する。WAI Applicationは標準インターフェースであるため、warp以外の
-- WAI対応サーバーでも動作させられる。
app :: Application
app = serve api server
