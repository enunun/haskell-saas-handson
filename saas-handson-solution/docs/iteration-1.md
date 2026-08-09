# Iteration 1：解説

## 実装する機能

`POST /users`（ユーザー登録）と`GET /users`（一覧取得）を実装する。データは
DBを使わずin-memory（`IORef`）で保持する。バリデーションや重複チェックは
行わない（Iteration 5で扱う）。ユーザーは`id`・`name`・`email`のみを持つ。

## リファクタリング：技術層別構成 → 機能別構成（Vertical Slice）

Iteration 0では`src/Api.hs`・`Server.hs`・`Types.hs`という技術層別の構成
だったが、これはHealthという1機能しか存在しなかったからこそ成立していた
（`docs/iteration-0.md`参照）。Iteration 1でUserという2つ目の機能が
加わるにあたり、まずHealthを`src/Health/{Api,Server,Types}.hs`へ移し、
Userも同じ形（`src/User/{Api,Server,Types}.hs`）で追加する。

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

ルートの`Api.hs`は各機能のAPI型を`:<|>`で合成するだけの薄いcombinatorに
なり、ルートの`Server.hs`も各機能の`server`値を合成するだけになる。
機能が増えるたびにこの合成箇所へ1行足すだけでよく、機能固有のルーティング
定義・ハンドラ実装は各機能のディレクトリ内に閉じる。

テスト（`test/unit`・`test/integration`）も同様に`Health/`・`User/`という
機能別サブディレクトリへ分割し、`src`と`test`のディレクトリ境界を一致させる。

## 設計パターン

### `:<|>`によるAPI合成

```haskell
type API = Health.API :<|> User.API
```

Servantでは複数のエンドポイント（型）を`:<|>`で連結でき、対応する実装
（`Server`値）も同じ形で`:<|>`により連結する。型と実装の構造が対応する
ため、片方だけ変更すればコンパイルエラーになる。

### `ReqBody`：リクエストボディの型レベル表現

```haskell
type API =
       "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> "users" :> Get '[JSON] [User]
```

`ReqBody '[JSON] CreateUserRequest`は、リクエストボディをJSONとしてパース
し`CreateUserRequest`型の値としてハンドラに渡すことを型で表現する。パースに
失敗した場合のエラー応答（400）はservant-serverが自動的に生成する。

### `PostCreated`（201） vs `Get`（200）

Iteration 1のPOST /usersはバリデーションを行わず、成功時は常に201
（Created）を返す前提のため`PostCreated`を用いる。Servantでは`Get`・
`PostCreated`・`Delete`などのVerb型がそれぞれ既定のステータスコードを
持ち、レスポンスの意味をエンドポイント定義自体に埋め込める。

### `IORef`によるハンドラ間state共有

```haskell
type Store = IORef (Int, [User])

server :: Store -> Server API
server store = createUserHandler :<|> listUsersHandler
  where
    createUserHandler req =
      liftIO $ atomicModifyIORef' store $ \(nextId, users) ->
        let newUser = User nextId (crName req) (crEmail req)
        in ((nextId + 1, users ++ [newUser]), newUser)
```

Iteration 0のHealthはハンドラが固定値を返すのみで状態を持たなかったが、
Userは登録・一覧という状態を持つ操作を扱う。そのためHealthの頃の
`server :: Server API`・`app :: Application`（引数なしの値）から、
`server :: Store -> Server API`・`mkApp :: Store -> Application`
（Storeを受け取る関数）に変わっている。`atomicModifyIORef'`で採番と
登録を単一の原子的操作として行うことで、複数リクエストが同時に来ても
採番id・一覧の破損を防ぐ。

### `CreateUserRequest`の手書き`FromJSON`インスタンス

```haskell
data User = User
  { userId :: Int, userName :: Text, userEmail :: Text }

data CreateUserRequest = CreateUserRequest
  { crName :: Text, crEmail :: Text }

instance FromJSON CreateUserRequest where
  parseJSON = withObject "CreateUserRequest" $ \v ->
    CreateUserRequest <$> v .: "name" <*> v .: "email"
```

`User`と`CreateUserRequest`が同じモジュール内で`name`・`email`という
同じフィールド名を使おうとすると、Haskellのレコードフィールド名は
モジュール内で一意である必要があるため衝突する（`id`はさらに
`Prelude.id`とも衝突する）。そこでHaskell側のフィールド名は
`userId`/`userName`/`userEmail`・`crName`/`crEmail`とずらし、
`withObject`・`.:`を使ってJSONキーは`id`/`name`/`email`のまま受け付ける
`FromJSON`/`ToJSON`インスタンスを手書きする。Iteration 0で使った
`deriving Generic`による自動導出（フィールド名がそのままJSONキーになる）
との対比になっている。

## 単体テスト・結合テストの役割分担が意味を持ち始める

`GET /health`は分岐のない固定値レスポンスだったため、単体テストと結合
テストの内容がほぼ一致していた。Userは「採番」「一覧の蓄積」という状態
遷移を持つため、この回から役割分担が実質的な意味を持つ。

- 単体テスト（`test/unit/User/UserSpec.hs`）：`runHandler`で`Handler`
  モナドを直接実行し、採番ロジックや一覧の順序といったドメインロジック
  をHTTP層なしで高速に検証する
- 結合テスト（`test/integration/User/UserSpec.hs`）：`hspec-wai`で
  実際にJSONボディを送り、ステータスコード・レスポンスのJSON構造まで
  含めて検証する

各テストは`with (mkApp <$> newStore)`（結合テスト）・テストごとの
`newStore`呼び出し（単体テスト）により、テストケースごとに新しい
`Store`を使う。これによりテスト間で登録済みユーザーの状態が漏れず、
`id`の採番結果を`1`のような具体的な値としてアサーションできる。

## 実装時に必要になるLANGUAGE拡張・依存パッケージ

Iteration 0のコードは、実際にビルドすると以下が不足しており、そのままでは
コンパイルが通らない（本教材のリファクタリングで修正済み）。Iteration 1で
同種のコードを書く際にも必要になるため、まとめておく。

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
