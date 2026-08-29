# Iteration 1：解説

このドキュメントは`../../exercise/docs/iteration-1.md`の演習問題に対応する
解答解説である。見出しの番号（1-1〜1-10）は演習側と対応している。

## 演習1-1の解説：Userの型・APIを読み解く

### フィールド名の同一モジュール内一意性制約

```haskell
-- src/User/Types.hs
data User = User { userId :: Int, userName :: Text, userEmail :: Text }
data CreateUserRequest = CreateUserRequest { crName :: Text, crEmail :: Text }
```

Haskellのレコードフィールドは、実は`userName :: User -> Text`のような
普通のトップレベル関数（フィールドアクセサ）として生成される。同じ
モジュール内で`User`の`name`と`CreateUserRequest`の`name`という2つの
フィールドを定義すると、`name :: User -> Text`と`name ::
CreateUserRequest -> Text`という同名・別の型を持つ関数が衝突し、
コンパイルエラーになる。回避策として`userName`・`crName`のように
プレフィックスをずらしている（`DuplicateRecordFields`という拡張機能で
同名を許すこともできるが、本教材では使わない）。

### 手書きの`FromJSON`

```haskell
-- src/User/Types.hs
instance FromJSON CreateUserRequest where
  parseJSON = withObject "CreateUserRequest" $ \v ->
    CreateUserRequest <$> v .: "name" <*> v .: "email"
```

`deriving (Generic)`＋`instance FromJSON CreateUserRequest`（中身は空）
という自動導出は、フィールド名がそのままJSONキーになる場合にしか使え
ない。`crName`というフィールド名のままGenericで導出すると、JSONキーも
`"crName"`になってしまい、実際のリクエストボディのキー`"name"`と
一致しない。フィールド名とJSONキーを一致させたい場合は、`withObject`・
`.:`を使って手書きする必要がある。

### `ReqBody`・`PostCreated`・`Capture`

```haskell
-- src/User/Api.hs
type API =
       "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> "users" :> Get '[JSON] [User]
  :<|> "users" :> Capture "id" Int :> Get '[JSON] User
```

1つ目：`POST /users`。リクエストボディをJSONとして`CreateUserRequest`
にパースし、成功時は201（Created）で`User`を返す。
2つ目：`GET /users`。`[User]`（配列）を返す。
3つ目：`GET /users/{id}`。`Capture "id" Int`はパスの`{id}`部分を`Int`
として受け取り、ハンドラの引数にする。

### `atomicModifyIORef'`

```haskell
-- src/User/Store.hs
createUser (Store ref) name email =
  atomicModifyIORef' ref $ \(nextId, users) ->
    let newUser = User nextId name email
    in ((nextId + 1, Map.insert nextId newUser users), newUser)
```

`readIORef`で読んでから`writeIORef`で書き戻す2ステップに分けると、
2つのリクエストが同時に来た場合、両方が同じ`nextId`を読んでしまい、
同じidを持つ2人のユーザーが作られてしまう（競合状態）。
`atomicModifyIORef'`は「現在の値を受け取り、（新しい値, 戻り値）の組を
返す関数」を1つの分割不可能な操作として実行するため、この競合が
起こらない。

以降の演習1-2〜1-6では、一度にすべてのテストを書いてから実装をまとめて
書くのではなく、1つの振る舞いについてテストを書いて失敗を確認し、それを
通す最小限の実装を書いて成功させる、というサイクルを1回ずつ繰り返す。
各節には、その時点での`server`の状態（まだ実装していない部分は
`error "TODO: ..."`のまま）を示す。

## 演習1-2の解説：ユーザーを1人作成する

```haskell
-- test/unit/User/UserSpec.hs
it "POST /usersでユーザーを作成すると、id=1から採番される" $ do
  store <- newStore
  let createUserHandler :<|> _ :<|> _ = server store
  result <- runHandler (createUserHandler (CreateUserRequest "Alice" "alice@example.com"))
  result `shouldBe` Right (User 1 "Alice" "alice@example.com")
```

`User.Server.server`は`Store -> Server API`という型を持ち、`:<|>`で
合成された3つのハンドラをまとめて返す。`let createUserHandler :<|> _ :<|> _
= server store`のようにパターンマッチすることで、必要なハンドラだけを
取り出して`runHandler`に渡せる。各テストで`newStore`を呼んで新しい
`Store`を用意しているため、テスト同士が状態を共有しない（前のテストで
作ったユーザーが次のテストに影響しない）。

このテストをGREENにする最小限の実装は、`createUserHandler`だけを
書くことである。`server`全体はこの時点で次の状態になる。

```haskell
-- src/User/Server.hs
server :: Store -> Server API
server store = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler :: CreateUserRequest -> Handler User
    createUserHandler req = liftIO (createUser store (crName req) (crEmail req))

    listUsersHandler :: Handler [User]
    listUsersHandler = error "TODO: Iteration 1で実装する"

    getUserHandler :: Int -> Handler User
    getUserHandler _uid = error "TODO: Iteration 1で実装する"
```

`User.Store`の`createUser`は`IO`の計算であり、`Handler`の中で使うには
`liftIO`で持ち上げる必要がある。

## 演習1-3の解説：2人目のユーザーを作成する

「続けてもう1人作成すると、id=2が採番される」というテストを追加しても、
演習1-2の`createUserHandler`はすでに`User.Store`の`atomicModifyIORef'`
による正しい採番に委譲しているため、追加のコード変更なしにGREENになる
（`server`の状態は演習1-2から変わらない）。テストを追加しても実装が
すでに正しく一般化されていて変更が要らない、というのもTDDでよくある
結果である。

## 演習1-4の解説：一覧取得

`listUsersHandler`を実装する。`server`は次の状態になる
（`createUserHandler`は演習1-2から変更なし）。

```haskell
-- src/User/Server.hs
server store = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler req = liftIO (createUser store (crName req) (crEmail req))

    listUsersHandler :: Handler [User]
    listUsersHandler = liftIO (listUsers store)

    getUserHandler _uid = error "TODO: Iteration 1で実装する"
```

## 演習1-5の解説：単一取得・成功

「作成済みユーザーのidで取得すると、そのユーザーが返る」テストを
通すのに必要なのは、`Just`の場合の処理だけである。`Nothing`の場合
（演習1-6で扱う404）は、まだテストが要求していないためTODOのままで
よい。

```haskell
-- src/User/Server.hs
getUserHandler :: Int -> Handler User
getUserHandler uid = do
  maybeUser <- liftIO (getUser store uid)
  case maybeUser of
    Just u  -> pure u
    Nothing -> error "TODO: Iteration 1で実装する"
```

## 演習1-6の解説：単一取得・404

「存在しないidで取得すると404が返る」テストを追加すると、演習1-5の
`Nothing`分岐がまだ`error "TODO"`のままなのでREDになる。
`Control.Monad.Except`の`throwError`で`err404`を投げるように直す
（Iteration 0の`getUserHandler`と同じパターンである）。

```haskell
-- src/User/Server.hs
getUserHandler :: Int -> Handler User
getUserHandler uid = do
  maybeUser <- liftIO (getUser store uid)
  case maybeUser of
    Just u  -> pure u
    Nothing -> throwError err404
```

これで`server`の3つのハンドラすべてが完成する。

## 演習1-7の解説：結合テストで同じ振る舞いを確認する

```haskell
-- test/integration/User/UserSpec.hs
request methodPost "/users" [("Content-Type", "application/json")]
  "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"
  `shouldRespondWith` [json|{id:1,name:"Alice",email:"alice@example.com"}|]
    { matchStatus = 201 }
```

`hspec-wai`の`request`はメソッド・パス・ヘッダ・ボディを指定して任意の
HTTPリクエストを送れる（`get`は`request "GET"`の省略形にすぎない）。
`OverloadedStrings`が有効なため、JSONの文字列リテラルをそのまま
`ByteString`のボディとして渡せる。`shouldRespondWith`の`{ matchStatus =
201 }`は、レスポンスボディだけでなくステータスコードも同時に検証
している。演習1-2〜1-6ですでにハンドラの実装を終えているため、この
結合テストは書いた時点でGREENになる。これは「結合テストが新しい実装を
駆動した」のではなく、「単体テストでは検証できなかった層（ルーティング・
JSONのフィールド名）が正しいことを、別の角度から確認した」という
位置づけである。

## 演習1-8の解説：Vertical Sliceへのリファクタリング

技術層別構成（`src/Api.hs`・`Server.hs`・`Types.hs`）は、1機能しか
なかった間は適切な選択だった。2つ目の機能（User）が増えると、この
ままでは1つの`Api.hs`にすべてのルート定義、1つの`Server.hs`にすべての
ハンドラが積み重なっていき、どのファイルを見ても機能ごとの境界が
見えなくなる。そこで機能（Health, User）ごとにAPI型・ハンドラ・データ
型をまとめるVertical Slice構成に移行する。

```haskell
-- src/Api.hs（合成後）
type API = Health.API :<|> User.API

-- src/Server.hs（合成後）
mkServer store = Health.server :<|> User.server store
mkApp store = serve api (mkServer store)
```

トップレベルの`Api.hs`・`Server.hs`は、各機能のAPI型・server値を
`:<|>`で合成するだけの薄いモジュールになる。`Health.Api`は`API`型だけを
エクスポートすればよく（`Proxy`は合成後の`API`に対して1つだけ作れば
よいため、トップレベルの`Api.hs`にのみ残す）、`Health.Server`は
`server :: Server Health.API`をエクスポートする。

この変更は振る舞いを一切変えないリファクタリングであり、
`cabal test saas-handson-solution-iteration1`の結果は変更前後で
変わらない（GREENのままGREEN）。

## 演習1-9の解説：単体テスト・結合テストへの影響を考える

問い1の答え：リファクタリング前、Healthの単体テスト・結合テストは
トップレベルの合成済み`mkServer`・`mkApp`を経由してHealthのハンドラに
たどり着いていた。リファクタリング後、`mkServer`・`mkApp`は`Store`
引数を要求するようになった（Userが状態を持つようになったため）。
Health自体は相変わらず状態を持たないが、**Healthのテストが呼び出して
いた入り口（トップレベルの合成済み関数）の型が変わった**ため、
呼び出し方を変える必要があった。

問い2の答え：単体テストは`Server (mkServer)`から`Health.Server (server)`
への切り替えだけで済む（`Store`が不要になる）。結合テストも同様に
`Server (mkApp)`（`Store`が必要）から、`Health.Api`・`Health.Server`
だけで`serve`したApplication（`Store`不要）への切り替えになる。どちらも
「呼び出す入り口を、合成済みの全体からHealth自身に変える」という
同じ理由による編集である。

問い3の答え：この編集が必要だったのは、Healthのテストが本来
必要としない情報（User機能のStore）に、トップレベルの合成済み関数を
経由していたために巻き込まれていたからである。Vertical Slice構成へ
移行し、各機能の単体テスト・結合テストがその機能自身のAPI型・
server値だけを相手にするようにしたことで、この巻き込まれが起きなく
なる。ある機能の変更が、無関係な機能のテストの書き方に影響しなくなる
という点が、この構成の狙いである。

## 演習1-10の解説（発展）：メールアドレスの重複を禁止する

`User.Store`の`Map Int User`はidをキーにしているため、メールアドレスの
重複を調べるには一覧を`Map.elems`で取り出して`any`で走査するか、
`Text`をキーにした別のMapを追加で持つ必要がある。重複が見つかった
場合にどう失敗を表現するか（`Maybe`で`Nothing`を返す、独自の
エラー型を作る等）は、Iteration 5で導入するドメインエラー型
（`UserError`）の設計を先取りする良い練習になる。

## 使用ライブラリ

| ライブラリ | 役割 |
|---|---|
| containers | `Data.Map.Strict`によるメモリ内ストア |
| mtl | `Control.Monad.Except`の`throwError` |
