module User.Store
  ( Store
  , newStore
  , createUser
  , listUsers
  , getUser
  ) where

import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import User.Types (User (..))

-- | 次に採番するidと、idをキーにしたユーザーの集合を1つのIORefにまとめて
-- 保持する。
newtype Store = Store (IORef (Int, Map Int User))

newStore :: IO Store
newStore = Store <$> newIORef (1, Map.empty)

-- | 採番と挿入を1つの分割不可能な操作として行う。複数のリクエストが
-- 同時にcreateUserを呼んでも、同じidが2回採番されることはない。
createUser :: Store -> Text -> Text -> IO User
createUser (Store ref) name email =
  atomicModifyIORef' ref $ \(nextId, users) ->
    let newUser = User nextId name email
    in ((nextId + 1, Map.insert nextId newUser users), newUser)

listUsers :: Store -> IO [User]
listUsers (Store ref) = Map.elems . snd <$> readIORef ref

getUser :: Store -> Int -> IO (Maybe User)
getUser (Store ref) uid = Map.lookup uid . snd <$> readIORef ref
