# Iteration 1：解説

このドキュメントは`saas-handson/docs/iteration-1.md`の演習問題に対応する
解答解説である。見出しの番号（1-1〜1-7）は演習側と対応している。

## 演習1-1の解説：User/CreateUserRequestの型を読み解く

```haskell
data User = User
  { userId    :: Int
  , userName  :: Text
  , userEmail :: Text
  } deriving (Show, Eq)

data CreateUserRequest = CreateUserRequest
  { crName  :: Text
  , crEmail :: Text
  } deriving (Show, Eq)

instance ToJSON User where
  toJSON (User uid uname uemail) =
    object ["id" .= uid, "name" .= uname, "email" .= uemail]

instance FromJSON CreateUserRequest where
  parseJSON = withObject "CreateUserRequest" $ \v ->
    CreateUserRequest <$> v .: "name" <*> v .: "email"
```

問い1の答え：Haskellのレコードフィールド名は同一モジュール内で一意で
ある必要がある。`User`と`CreateUserRequest`が同じモジュール内でともに
`name`・`email`というフィールド名を使おうとすると衝突する。そこで
Haskell側のフィールド名は`userName`/`crName`のようにずらし、`withObject`
・`.:`・`.=`を使ってJSONキーは`id`/`name`/`email`のままにする`ToJSON`/
`FromJSON`インスタンスを手書きする。

問い2の答え：`deriving (Generic)`による自動導出は、フィールド名がその
ままJSONキーになる場合にしか使えない。`User`・`CreateUserRequest`は
問い1の理由でHaskell側のフィールド名をJSONキーからずらしているため、
自動導出をそのまま使うとJSONキーが`userId`/`userName`のようになって
しまう。キー名を`id`/`name`/`email`に保つには、`withObject`・`.:`・`.=`
を使った手書きのインスタンスが必要になる。これがIteration 0の
`HealthResponse`（フィールド名とJSONキーが一致するため`deriving
(Generic)`で足りる）との対比になっている。

問い3の答え：`id`というフィールド名を`User`のフィールドとして直接使うと、
`Prelude`が提供する恒等関数`id :: a -> a`と名前が衝突する。この衝突を
避けるため`userId`という名前にし、JSONキーとしての`"id"`は`ToJSON`/
`FromJSON`インスタンスの中で文字列リテラルとして扱う。

## 演習1-2の解説：listUsersHandlerを実装する

### IORefによるハンドラ間state共有

```haskell
type Store = IORef (Int, [User])

newStore :: IO Store
newStore = newIORef (1, [])
```

Iteration 0のHealthはハンドラが固定値を返すのみで状態を持たなかったが、
Userは登録・一覧という状態を持つ操作を扱う。そのためHealthの頃の
`server :: Server API`・`app :: Application`（引数なしの値）から、
`server :: Store -> Server API`・`mkApp :: Store -> Application`
（Storeを受け取る関数）に変わっている。

### listUsersHandlerの実装

```haskell
listUsersHandler :: Handler [User]
listUsersHandler = liftIO (snd <$> readIORef store)
```

`Store`は`(次に採番するid, 登録済みユーザー一覧)`のタプルであるため、
一覧を返すには`readIORef`で現在の値を読み出し、`snd`でユーザー一覧の
部分だけを取り出せばよい。`readIORef`は`IO`アクションであるため、
`Handler`モナドの中で使うには`liftIO`で持ち上げる。読み取りのみで
カウンタを変更しないため、Userの2つのハンドラの中では最も単純である。

## 演習1-3の解説：createUserHandlerを実装する

### `ReqBody`：リクエストボディの型レベル表現

```haskell
type API =
       "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> "users" :> Get '[JSON] [User]
```

`ReqBody '[JSON] CreateUserRequest`は、リクエストボディをJSONとして
パースし`CreateUserRequest`型の値としてハンドラに渡すことを型で表現
する。パースに失敗した場合のエラー応答（400）はservant-serverが自動的
に生成する。

### `PostCreated`（201）

Iteration 1の`POST /users`はバリデーションを行わず、成功時は常に201
（Created）を返す前提のため`PostCreated`を用いる。Servantでは`Get`・
`PostCreated`・`Delete`などのVerb型がそれぞれ既定のステータスコードを
持ち、レスポンスの意味をエンドポイント定義自体に埋め込める。

### createUserHandlerの実装

```haskell
createUserHandler :: CreateUserRequest -> Handler User
createUserHandler (CreateUserRequest reqName reqEmail) =
  liftIO $ atomicModifyIORef' store $ \(nextId, users) ->
    let newUser = User nextId reqName reqEmail
    in ((nextId + 1, users ++ [newUser]), newUser)
```

`atomicModifyIORef'`は「現在の値を読み、新しい値を計算し、書き戻す」を
単一の原子的操作として行う。採番（`nextId`の消費）とユーザー一覧への
追加を分けて`readIORef`・`writeIORef`で行うと、複数のリクエストが同時
に来た際に同じidが2回採番されたり、片方の更新が失われたりする競合状態
が起こりうる。`atomicModifyIORef'`を使うことでこれを防ぐ。

## 演習1-4の解説：テストをすべてGREENにする

### 単体テスト・結合テストの役割分担が意味を持ち始める

`GET /health`は分岐のない固定値レスポンスだったため、単体テストと結合
テストの内容がほぼ一致していた。Userは「採番」「一覧の蓄積」という状態
遷移を持つため、この回から役割分担が実質的な意味を持つ。

- 単体テスト（`test/unit/User/UserSpec.hs`）：`runHandler`で`Handler`
  モナドを直接実行し、採番ロジックや一覧の順序といったドメインロジック
  をHTTP層なしで高速に検証する。
- 結合テスト（`test/integration/User/UserSpec.hs`）：`hspec-wai`で実際
  にJSONボディを送り、ステータスコード・レスポンスのJSON構造まで含めて
  検証する。

各テストは`with (mkApp <$> newStore)`（結合テスト）・テストごとの
`newStore`呼び出し（単体テスト）により、テストケースごとに新しい
`Store`を使う。これによりテスト間で登録済みユーザーの状態が漏れず、
idの採番結果を`1`のような具体的な値としてアサーションできる。「2件
作成すると異なるidが採番される」「作成順に全件返す」がGREENになって
いれば、`atomicModifyIORef'`による採番とリストへの追加が意図どおりに
動いていることが確認できたことになる。

## 演習1-5の解説：リファクタリング（技術層別構成→機能別構成）

```
src/
  Health/
    Api.hs      -- "health" :> Get '[JSON] HealthResponse
    Server.hs   -- server :: Server API
    Types.hs    -- HealthResponse
  User/
    Api.hs      -- "users" :> ... :<|> "users" :> ...
    Server.hs   -- server :: Store -> Server API
    Types.hs    -- User, CreateUserRequest
  Api.hs        -- type API = Health.API :<|> User.API
  Server.hs     -- mkServer/mkApp（機能ごとのserverを:<|>で合成）
```

### `:<|>`によるAPI合成

```haskell
type API = Health.API :<|> User.API
```

```haskell
mkServer :: Store -> Server API
mkServer store = Health.server :<|> User.server store
```

Servantでは複数のエンドポイント（型）を`:<|>`で連結でき、対応する実装
（`Server`値）も同じ形で`:<|>`により連結する。型と実装の構造が対応する
ため、片方だけ変更すればコンパイルエラーになる。ルートの`Api.hs`は各
機能のAPI型を`:<|>`で合成するだけの薄いcombinatorになり、ルートの
`Server.hs`も各機能の`server`値を合成するだけになる。機能が増えるたび
にこの合成箇所へ1行足すだけでよく、機能固有のルーティング定義・ハンドラ
実装は各機能のディレクトリ内に閉じる。

テスト（`test/unit`・`test/integration`）も同様に`Health/`・`User/`と
いう機能別サブディレクトリへ分割し、`src`と`test`のディレクトリ境界を
一致させる。移動そのものは挙動を変えない操作であるため、移動の前後で
`cabal test saas-handson`の結果（成功・失敗の内容）が変わらないことで、
純粋なRefactorステップであったことを確認できる。

## 演習1-6の解説（発展）：疎通確認と設計の一般化、トラブルシューティング

3つ目の機能を追加する場合、`src/Comment/{Api,Server,Types}.hs`・
`test/{unit,integration}/Comment/CommentSpec.hs`を新規に作り、ルートの
`src/Api.hs`の`:<|>`連結に`Comment.API`を1行足し、`src/Server.hs`の
`:<|>`連結に`Comment.server`を1行足す。`saas-handson.cabal`の
`exposed-modules`・`other-modules`にも新規ファイルを追加する。既存の
Health・Userのコードには一切手を入れずに済む点が、機能別構成の恩恵で
ある。

### 実装時に必要になるLANGUAGE拡張・依存パッケージ

演習1-6でフィールドを追加する場合など、Iteration 0・1と同種のコードを
自分で書く際に必要になる拡張・依存をまとめておく。

| 用途 | 拡張／依存 |
|---|---|
| `type API = "health" :> Get '[JSON] HealthResponse`のような型レベルの`:>`・`'[JSON]` | `{-# LANGUAGE DataKinds #-}`, `{-# LANGUAGE TypeOperators #-}` |
| `deriving (Generic)`からの`ToJSON`/`FromJSON`自動導出 | `{-# LANGUAGE DeriveGeneric #-}` |
| `Text`型のフィールドに文字列リテラルを渡す（例：`HealthResponse "ok"`） | `{-# LANGUAGE OverloadedStrings #-}` |
| hspec-waiの`[json\|...\|]`クオート | `{-# LANGUAGE QuasiQuotes #-}`、および`.cabal`への`hspec-wai-json`の追加 |
| `import Servant.API`（`servant`パッケージのモジュール） | `servant`を直接`build-depends`に追加するか、代わりに`servant-server`が再エクスポートする`import Servant`を使う（本教材は後者を採用） |
| `warp`の`run`（`GHC.Internal.Event.Thread.getSystemTimerManager`実行時エラー） | executableの`.cabal`に`ghc-options: -threaded`を追加し、GHCのthreaded runtimeでリンクする |

`cabal build`・`cabal test`を実行した際に「Could not load module」や
「Couldn't match type '[Char]' with 'Text'」のようなエラーが出た場合は、
上記のいずれかが不足している可能性が高い。

## 演習1-7の解説：getUserHandlerを実装する（GET /users/{id}）

### Capture：パスパラメータの型レベル表現

```haskell
type API =
       AuthProtect "jwt" :> "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> AuthProtect "jwt" :> "users" :> Get '[JSON] [User]
  :<|> AuthProtect "jwt" :> "users" :> Capture "id" Int :> Get '[JSON] User
```

`Capture "id" Int`は、パスの該当セグメントを`Int`としてパースしハンドラ
に渡すことを型で表現する。パースに失敗した場合（例：`/users/abc`という
数値でないパス）の400応答はservant-serverが自動的に生成する。

### getUserImplの実装（in-memory）

```haskell
getUserImpl :: IORef (Int, Map TenantId [User]) -> TenantId -> Int -> IO (Maybe User)
getUserImpl store tenantId targetId = do
  (_, tenants) <- readIORef store
  pure (find ((== targetId) . userId) (Map.findWithDefault [] tenantId tenants))
```

`listUsersImpl`と同じく該当テナントのユーザー一覧をまず取り出したうえで、
`Data.List.find`で`userId`が一致する要素を探す。`find`は見つからなければ
`Nothing`を返すため、そのまま`UserRepository`の型シグネチャ
（`IO (Maybe User)`）に一致する。

### getUserImplの実装（PostgreSQL）

```haskell
getUserImpl :: Pool Connection -> TenantId -> Int -> IO (Maybe User)
getUserImpl pool tenantId targetId =
  withResource pool $ \conn -> do
    rows <- query conn
      "SELECT id, name, email FROM users WHERE tenant_id = ? AND id = ?"
      (unTenantId tenantId, targetId)
    pure (listToMaybe rows)
```

`WHERE tenant_id = ? AND id = ?`でテナント境界とid一致の両方を1つのSQL
文に含めている。他テナントのidを指定した場合も0行になるため、
「存在しない」場合と「他テナントのものだった」場合を区別なく`Nothing`
として扱える（他テナントのデータの存在自体をレスポンスから漏らさない
という設計はIteration 3の方針をそのまま踏襲している）。`listToMaybe`
（`Data.Maybe`）は0件なら`Nothing`、1件以上なら先頭要素を`Just`で包む
（idはテーブルのPRIMARY KEYなので実際には0件か1件にしかならない）。

### getUserHandlerの実装

```haskell
getUserHandler :: AuthenticatedUser -> Int -> Handler User
getUserHandler authUser targetId = do
  maybeUser <- liftIO (getUser repo (authTenantId authUser) targetId)
  case maybeUser of
    Just foundUser -> pure foundUser
    Nothing        -> throwError err404
```

`UserError`（`Forbidden`・`InvalidEmail`）はIteration 5で導入される
「権限がない・入力が不正」という種類のドメインエラーであり、「リソース
がそもそも存在しない」という単純な404はこの型に含めていない。
`Servant.err404`を`Control.Monad.Except.throwError`で直接投げることで、
Iteration 5の`UserError`／`toServerError`機構に依存せず、このIteration
の中で完結させている（`listUsersHandler`が`createUserHandler`のような
権限チェック・ログ出力を持たないのと同じ理由で、`getUserHandler`も
単純さを保っている）。
