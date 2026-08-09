module Main (main) where

import Network.Wai.Handler.Warp (run)
import Server (app)

main :: IO ()
main = do
  putStrLn "listening on port 8080"
  run 8080 app
