module Main (main) where

import Auth.Server (newJWKStore)
import Network.Wai.Handler.Warp (run)
import Server (mkApp)
import User.Store (newStore)

-- | mock-oauth2-server（devcontainerのdocker composeで一緒に起動する
-- mock-authサービス）が公開するJWKS URI。"mock-auth"はdocker compose
-- ネットワーク上のサービス名で、コンテナ内ポート8080で解決できる。
jwksUri :: String
jwksUri = "http://mock-auth:8080/default/jwks"

main :: IO ()
main = do
  store <- newStore
  jwkStore <- newJWKStore jwksUri
  putStrLn "listening on port 8080"
  run 8080 (mkApp jwkStore store)
