module Logging
  ( Logger (..)
  , LogLevel (..)
  , LogEntry (..)
  , logInfo
  , logWarn
  ) where

import Data.Text (Text)

data LogLevel = Info | Warn deriving (Show, Eq)

-- | 1件のログ出力を表す。messageは"user_created"のような、機械的に
-- 検索・集計しやすい固定の識別子とし、可変の詳細（誰が・どのテナントか
-- 等）はfieldsという構造化された付随情報として分離する。この分離は
-- 「メッセージ文字列の中に値を埋め込む」ログと対照的な、構造化ログ
-- （structured logging）の考え方である。
data LogEntry = LogEntry
  { logEntryLevel   :: LogLevel
  , logEntryMessage :: Text
  , logEntryFields  :: [(Text, Text)]
  } deriving (Show, Eq)

-- | ロギングの出力先を抽象化するインターフェース。UserRepositoryと同じ
-- レコード・オブ・関数（Handleパターン）で表現する。実装は
-- Logging.Stdout（本番用、標準出力へJSON行として出力する）・
-- Logging.Capturing（テスト用、出力をメモリに溜める）の2つを用意する。
newtype Logger = Logger
  { logEntry :: LogEntry -> IO ()
  }

logInfo, logWarn :: Logger -> Text -> [(Text, Text)] -> IO ()
logInfo logger msg fields = logEntry logger (LogEntry Info msg fields)
logWarn logger msg fields = logEntry logger (LogEntry Warn msg fields)
