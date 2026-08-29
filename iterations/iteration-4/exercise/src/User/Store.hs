module User.Store
  ( Store
  , newStore
  , createUser
  , listUsers
  , getUser
  ) where

import Auth.Types (TenantId)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import User.Types (User (..))

-- | テナントごとに、次に採番するidと、idをキーにしたユーザーの集合を
-- 保持する。テナント間でidの採番系列も完全に分離される（テナントAの
-- 1人目とテナントBの1人目が、どちらもid=1になりうる）。
newtype Store = Store (IORef (Map TenantId (Int, Map Int User)))

newStore :: IO Store
newStore = Store <$> newIORef Map.empty

-- | 指定したテナントの採番と挿入を1つの分割不可能な操作として行う。
createUser :: Store -> TenantId -> Text -> Text -> IO User
createUser (Store ref) tenantId name email =
  atomicModifyIORef' ref $ \tenants ->
    let (nextId, users) = Map.findWithDefault (1, Map.empty) tenantId tenants
        newUser = User nextId name email
        tenants' = Map.insert tenantId (nextId + 1, Map.insert nextId newUser users) tenants
    in (tenants', newUser)

listUsers :: Store -> TenantId -> IO [User]
listUsers (Store ref) tenantId = do
  tenants <- readIORef ref
  pure (Map.elems (snd (Map.findWithDefault (1, Map.empty) tenantId tenants)))

-- | 他テナントのidを指定した場合もNothingを返す（そのテナントの
-- ユーザー集合の中にそのidが存在しないため）。
getUser :: Store -> TenantId -> Int -> IO (Maybe User)
getUser (Store ref) tenantId uid = do
  tenants <- readIORef ref
  pure (Map.lookup uid (snd (Map.findWithDefault (1, Map.empty) tenantId tenants)))
