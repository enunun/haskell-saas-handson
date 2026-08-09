{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Auth.Server (newJWKStore)
import Data.ByteString (ByteString)
import Logging.Stdout (newStdoutLogger)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
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

-- | logStdoutDevはリクエスト単位のアクセスログ（メソッド・パス・
-- ステータスコード等）をWAIミドルウェアとして付与する（wai-extra）。
-- これはHTTPというトランスポート層の出来事を記録するもので、
-- Logging（User.Serverが使う、ドメインイベントを表す構造化ログ）とは
-- 役割が異なる。両方を組み合わせることで、「HTTPレベルで何が起きたか」
-- と「ビジネスロジックとして何が起きたか」の両方を追跡できる。
main :: IO ()
main = do
  logger <- newStdoutLogger
  repo <- newPostgresUserRepository dbConnStr
  jwkStore <- newJWKStore jwksUri
  putStrLn "listening on port 8080"
  run 8080 (logStdoutDev (mkApp jwkStore logger repo))
