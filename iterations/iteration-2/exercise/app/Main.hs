module Main (main) where

import Network.Wai.Handler.Warp (run)
import Server (mkApp)
import User.Store (newStore)

main :: IO ()
main = do
  store <- newStore
  putStrLn "listening on port 8080"
  run 8080 (mkApp store)
