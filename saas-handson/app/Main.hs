{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Auth.Server (newJWKStore)
import Data.ByteString (ByteString)
import Network.Wai.Handler.Warp (run)
import Server (mkApp)
import User.Repository.Postgres (newPostgresUserRepository)

-- | mock-oauth2-server（devcontainerのdocker composeで一緒に起動する
-- mock-authサービス）が公開するJWKS URI。"mock-auth"はdocker compose
-- ネットワーク上のサービス名で、コンテナ内ポート8080で解決できる。
jwksUri :: String
jwksUri = "http://mock-auth:8080/default/jwks"

-- | devcontainerのdocker composeで一緒に起動するdbサービス（PostgreSQL）
-- への接続文字列。"db"はdocker composeネットワーク上のサービス名で、
-- コンテナ内ポート5432で解決できる。
dbConnStr :: ByteString
dbConnStr = "host=db port=5432 dbname=saas_handson user=postgres password=postgres"

main :: IO ()
main = do
  repo <- newPostgresUserRepository dbConnStr
  jwkStore <- newJWKStore jwksUri
  putStrLn "listening on port 8080"
  run 8080 (mkApp jwkStore repo)
