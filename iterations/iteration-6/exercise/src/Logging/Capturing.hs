module Logging.Capturing
  ( newCapturingLogger
  ) where

import Logging (LogEntry, Logger (..))

-- | TODO: 出力先を標準出力ではなくメモリ上のリストにしたLogger実装を
-- 完成させ、test/unit/User/UserSpec.hsで「特定の状況で正しくログが
-- 呼ばれたか」を検証できるようにすること。
--
-- ヒント：
-- - `Control.Concurrent.MVar`の`newMVar`・`modifyMVar_`・`readMVar`を
--   使う（`Data.IORef`の`atomicModifyIORef'`と同様、複数のリクエストが
--   同時にログを書いても記録が失われない・混ざらないようにするため）。
-- - 戻り値の1つ目が`Logger`、2つ目がその時点までに記録された
--   `[LogEntry]`を記録順に返す`IO [LogEntry]`になるようにする。
newCapturingLogger :: IO (Logger, IO [LogEntry])
newCapturingLogger = error "TODO: Iteration 6で実装する"
