{-# LANGUAGE OverloadedStrings #-}

module Logging.Stdout
  ( newStdoutLogger
  ) where

import Data.Aeson (Value (String), encode, object, (.=))
import qualified Data.Aeson.Key as Key
import Data.Text (Text)
import Data.Time (getCurrentTime)
import Data.Time.Format (defaultTimeLocale, formatTime)
import Logging (LogEntry (..), LogLevel (..), Logger (..))
import System.Log.FastLogger
  ( defaultBufSize
  , flushLogStr
  , newStdoutLoggerSet
  , pushLogStrLn
  , toLogStr
  )

-- | 標準出力へ1行1JSONのログを出力するLogger実装。
--
-- fast-loggerは複数のHaskellスレッド（Warpは各リクエストを別スレッドで
-- 処理する）から同時に呼ばれても、出力が1行の途中で混ざらないことを
-- 保証しつつ高速に書き込めるように設計されたロギング基盤である。生の
-- putStrLnを複数スレッドから直接呼ぶと、複数行の出力が交互に混ざって
-- しまう（interleaveされる）ことがあるが、fast-loggerのLoggerSetは
-- これを防ぐ。
newStdoutLogger :: IO Logger
newStdoutLogger = do
  loggerSet <- newStdoutLoggerSet defaultBufSize
  pure Logger { logEntry = writeEntry loggerSet }
  where
    writeEntry loggerSet entry = do
      now <- getCurrentTime
      let json = object
            [ "timestamp" .= formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%QZ" now
            , "level" .= levelText (logEntryLevel entry)
            , "message" .= logEntryMessage entry
            , "fields" .= object [Key.fromText k .= String v | (k, v) <- logEntryFields entry]
            ]
      pushLogStrLn loggerSet (toLogStr (encode json))
      flushLogStr loggerSet

levelText :: LogLevel -> Text
levelText Info = "info"
levelText Warn = "warn"
