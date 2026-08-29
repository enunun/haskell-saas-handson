module Logging.Capturing
  ( newCapturingLogger
  ) where

import Control.Concurrent.MVar (modifyMVar_, newMVar, readMVar)
import Logging (LogEntry, Logger (..))

-- | 出力先を標準出力ではなくメモリ上のリストにしたLogger実装。テストで
-- 「特定の状況で正しくログが呼ばれたか」を検証するために使う
-- （User.Repository.InMemoryが実DBを必要とせずにUserRepositoryを
-- テストできるようにしたのと同じ狙い）。
--
-- 戻り値の2つ目（IO [LogEntry]）を呼ぶたびに、その時点までに記録された
-- ログをすべて記録順に取得できる。
newCapturingLogger :: IO (Logger, IO [LogEntry])
newCapturingLogger = do
  entriesVar <- newMVar []
  let logger = Logger { logEntry = \e -> modifyMVar_ entriesVar (\es -> pure (es ++ [e])) }
  pure (logger, readMVar entriesVar)
