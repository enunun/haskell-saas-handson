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

-- | TODO: writeEntryを実装し、test/unit/Logging/StdoutSpec.hsをGREENに
-- すること。
-- ヒント：
-- - Data.Aeson.objectで、"timestamp"・"level"・"message"・"fields"の
--   4フィールドを持つJSONの値を組み立てる。"fields"の値はさらに
--   logEntryFieldsを1つのJSONオブジェクトに変換したもの（キーは
--   Data.Aeson.Key.fromTextでTextからKeyへ変換する）。
-- - levelにはlevelText（下に定義済み）でLogLevelを文字列化したものを使う。
-- - Data.Aeson.encodeでJSONの値をByteStringにエンコードし、
--   System.Log.FastLogger.toLogStrでLogStrに変換して
--   System.Log.FastLogger.pushLogStrLnで書き込む。
-- - fast-loggerは内部でバッファリングするため、書き込み後に
--   System.Log.FastLogger.flushLogStrを呼んで即座に出力させる
--   （呼ばないと、テストやcabal run程度の短い実行時間ではログが
--   標準出力に一切現れないことがある）。
writeEntry :: LoggerSet -> LogEntry -> IO ()
writeEntry _loggerSet _entry = error "TODO: Iteration 6で実装する"

levelText :: LogLevel -> Text
levelText Info  = "info"
levelText Warn  = "warn"
levelText Error = "error"
