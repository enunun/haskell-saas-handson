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
  ( LoggerSet
  , defaultBufSize
  , flushLogStr
  , newStdoutLoggerSet
  , pushLogStrLn
  , toLogStr
  )

-- | 標準出力へ1行1JSONのログを出力するLogger実装。
--
-- fast-loggerは複数のHaskellスレッド（Warpは各リクエストを別スレッドで
-- 処理する）から同時に呼ばれても、出力が1行の途中で混ざらないことを
-- 保証しつつ高速に書き込めるように設計されたロギング基盤である。
-- 生のSystem.IO.putStrLnを複数スレッドから直接呼ぶと、複数の行の
-- 出力が交互に混ざってしまう（interleaveされる）ことがあるが、
-- fast-loggerのLoggerSetはこれを防ぐ。
newStdoutLogger :: IO Logger
newStdoutLogger = do
  loggerSet <- newStdoutLoggerSet defaultBufSize
  pure Logger { logEntry = writeEntry loggerSet }

writeEntry :: LoggerSet -> LogEntry -> IO ()
writeEntry loggerSet entry = do
  now <- getCurrentTime
  let json = object
        [ "timestamp" .= formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%QZ" now
        , "level" .= levelText (logEntryLevel entry)
        , "message" .= logEntryMessage entry
        , "fields" .= object [Key.fromText k .= String v | (k, v) <- logEntryFields entry]
        ]
  pushLogStrLn loggerSet (toLogStr (encode json))
  -- リクエスト処理と同じ短命なプロセス（devcontainer上でのcabal run等）
  -- でも即座にログが確認できるよう、書き込みのたびに明示的にflushする。
  -- 高スループットな本番運用では、バッファがある程度溜まってから
  -- まとめてflushする方が効率的な場合もある。
  flushLogStr loggerSet

levelText :: LogLevel -> Text
levelText Info  = "info"
levelText Warn  = "warn"
levelText Error = "error"
