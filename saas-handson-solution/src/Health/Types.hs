{-# LANGUAGE DeriveGeneric #-}

module Health.Types
  ( HealthResponse (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

-- | ヘルスチェックAPIのレスポンス型。
--
-- deriving Genericにより、JSON変換用のインスタンスを
-- ボイラープレートなしで導出できる。
newtype HealthResponse = HealthResponse
  { status :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON HealthResponse
instance FromJSON HealthResponse
