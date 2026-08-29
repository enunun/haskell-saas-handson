# Iteration 4：解説

このドキュメントは`../../exercise/docs/iteration-4.md`の演習問題に対応する
解答解説である。見出しの番号（4-1〜4-6）は演習側と対応している。

## 演習4-1の解説：Repository層を読み解く

### 型クラスではなくレコード（Handleパターン）

```haskell
-- src/User/Repository.hs
data UserRepository = UserRepository
  { createUser :: TenantId -> Text -> Text -> IO User
  , listUsers  :: TenantId -> IO [User]
  , getUser    :: TenantId -> Int -> IO (Maybe User)
  }
```

型クラスにすると、「どの実装を使うか」はコンパイル時に型として静的に
1つに決まる。このアプリケーションでは、同じ実行時に複数の実装を切り替える
必要はない（本番はPostgreSQL、テストはin-memory、という使い分けは
「どちらの値を組み立てて渡すか」で済む）。`newPostgresUserRepository`
は接続プールを`IO`アクションの中で作り、`UserRepository`の各フィールドの
クロージャにその`Pool Connection`を閉じ込めている。値として持ち回れる
ため、この組み立て方が型クラスより素直にできる。

### SERIAL＋RETURNING idの効果

```haskell
-- src/User/Repository/Postgres.hs
[Only newId] <- query conn
  "INSERT INTO users (tenant_id, name, email) VALUES (?, ?, ?) RETURNING id"
  (unTenantId tenantId, name, email)
```

Iteration 3の`atomicModifyIORef'`は、「今の次のid」を読み、それを使って
新しいユーザーを作り、「次のid+1」に更新する、という一連の操作を
アプリケーション側で分割不可能に行う責務を負っていた。PostgreSQLの
`SERIAL`列は、複数のコネクションから同時に`INSERT`されても重複しない
連番を発行することをDBが保証する。`RETURNING id`で、その場で採番された
idをアプリケーション側が受け取れるため、「採番のための読み取り→計算→
書き込み」をアプリケーション側で組み立てる必要が一切なくなる。

### `Pool`・`withResource`

`postgresql-simple`の`Connection`は、1つのコネクションを複数のスレッドが
同時に使うことを想定していない（同じソケットに対して同時にクエリを
送ると、レスポンスが混線しうる）。`resource-pool`の`Pool Connection`は、
あらかじめ複数のコネクションを用意しておき、`withResource`で「1つ借りて、
使い終わったら返す」という借用パターンを提供する。Webサーバーの各
リクエストスレッドは、プールに空きがあれば互いに待たされることなく
並行してDBにアクセスできる。

### `orphan instance`をどこに置くか

```haskell
-- src/User/Repository/Postgres.hs
instance FromRow User where
  fromRow = User <$> field <*> field <*> field
```

`User`は`User.Types`に、`FromRow`は`postgresql-simple`に、それぞれ別の
モジュールで定義されている型クラスである。このインスタンスを
`User.Types`に置くと、`User.Types`が`postgresql-simple`（DB固有の
ライブラリ）に依存することになってしまう。`User.Types`はどんな永続化
方式を使うかを知らないままでいてほしいため、DBの行変換ロジックは
`User.Repository.Postgres`（PostgreSQL実装の中）に局所化している。

## 演習4-2の解説：in-memory実装を完成させる

```haskell
-- src/User/Repository/InMemory.hs
newInMemoryUserRepository :: IO UserRepository
newInMemoryUserRepository = do
  ref <- newIORef Map.empty
  pure UserRepository
    { createUser = \tenantId name email ->
        atomicModifyIORef' ref $ \tenants ->
          let (nextId, users) = Map.findWithDefault (1, Map.empty) tenantId tenants
              newUser = User nextId name email
              tenants' = Map.insert tenantId (nextId + 1, Map.insert nextId newUser users) tenants
          in (tenants', newUser)
    , ...
    }
```

Iteration 3の`User.Store`とロジックは同じである。違いは、`Store`という
専用の型を作らず、`IORef`を`newInMemoryUserRepository`のクロージャに
直接閉じ込め、3つの関数を`UserRepository`のフィールドとして組み立てる
点だけである。

## 演習4-3の解説：既存のコードをUserRepositoryへ切り替える

```haskell
-- src/User/Server.hs
server :: UserRepository -> Server API
server repo = createUserHandler :<|> listUsersHandler :<|> getUserHandler
  where
    createUserHandler authUser req =
      liftIO (createUser repo (authTenantId authUser) (crName req) (crEmail req))
    ...
```

`User.Server`のハンドラの中身は、Iteration 3の`Store`版とほぼ1文字も
変わらない（`store`が`repo`になっただけである）。これが「ハンドラの
実装をデータ格納方式から独立させる」ことの具体的な効果であり、
`UserRepository`という抽象化を導入したことで、ハンドラは相手が
in-memoryなのかPostgreSQLなのかを一切意識しなくてよくなっている。

## 演習4-4の解説：結合テストをPostgreSQLに切り替える

```haskell
-- test/integration/User/UserSpec.hs
mkTestApp :: JWK -> IO Application
mkTestApp jwk = do
  conn <- connectPostgreSQL dbConnStr
  _ <- execute_ conn "TRUNCATE TABLE users RESTART IDENTITY"
  close conn
  repo <- newPostgresUserRepository dbConnStr
  pure (serveWithContext (Proxy :: Proxy User.API) (authContext (mkJWKStore (JWKSet [jwk]))) (server repo))
```

hspec-waiの`with`に渡した`IO Application`は、各テストケースの実行前に
毎回呼び出される。in-memory実装であれば、この仕組みだけで各テストが
独立した状態（新しい`IORef`）を持てていた。実DBのテーブルは、
アプリケーションを再構築してもデータそのものは消えない（同じテーブルを
指し続ける）ため、各テストの前に明示的に`TRUNCATE TABLE users RESTART
IDENTITY`でテーブルを空にし、`SERIAL`の採番も1から始まるようにして
いる。

## 演習4-5の解説：単体テスト・結合テストへの影響を考える

問い1の答え：`User.Server`は`UserRepository`という抽象化された
インターフェースしか知らないため、単体テストがin-memory実装を、
結合テストがPostgreSQL実装を注入しても、`User.Server`側のコードは
一切変更する必要がない。これはIteration 0〜3の`Health`（状態を持たない
ので該当しない）・`Auth`（`JWKStore`は`mkJWKStore`／`newJWKStore`という
2つの作り方を最初から持っていた）と同じ設計方針の延長線上にあり、
「本番用の実装とテスト用の実装を差し替えられるようにする」という
考え方をデータアクセス層にも適用したものである。

問い2の答え：in-memory実装の状態（`IORef`）は、Applicationを再構築する
たびに新しく作られるため、テスト間で自然に独立している。実DBの
テーブルは、Applicationの再構築とは無関係に存在し続ける共有資源で
あるため、明示的に後始末（`TRUNCATE`）をしない限り、あるテストで
作ったデータが次のテストに残ってしまう。

## 使用ライブラリ

| ライブラリ | 役割 |
|---|---|
| postgresql-simple | PostgreSQLへの接続・クエリ実行 |
| resource-pool | コネクションプール（`Pool`・`withResource`） |
