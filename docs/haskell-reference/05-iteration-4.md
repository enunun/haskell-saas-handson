# Iteration 4：永続化層の導入

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 3：マルチテナント対応](04-iteration-3.md)

## Handleパターン（DI）とレコード・オブ・関数

`src/User/Repository.hs`は次のように定義されている（`getUser`フィールド
は省略する）。

```haskell
data UserRepository = UserRepository
  { createUser :: TenantId -> Text -> Text -> IO User
  , listUsers  :: TenantId -> IO [User]
  }
```

オブジェクト指向言語では、「実装を差し替えられるようにする」ために
インターフェース（Java／C#等）やプロトコル（他言語）を定義し、
実行時に具体的な実装を注入する（Dependency Injection、DI）ことが
よく行われる。Haskellにはクラスやインターフェースという言語機能は
ないが、**関数をフィールドに持つ普通のレコード型**（Handleパターンと
呼ばれる）で同じことができる。`UserRepository`は「`createUser`・
`listUsers`という2つの操作を持つ値」であり、その中身がIORefで実装
されているかPostgreSQLで実装されているかは、この型を使う側
（`User.Server`）からは一切分からない・気にしなくてよい。「注入」は
特別な仕組みを必要とせず、単に関数の引数としてこの値を渡すだけで
実現できる。

## クロージャで内部状態を隠す

`src/User/Repository/InMemory.hs`の要点を、変数名を`store`に簡略化して
示す。

```haskell
newInMemoryUserRepository :: IO UserRepository
newInMemoryUserRepository = do
  store <- newIORef Map.empty
  pure UserRepository
    { createUser = \tenantId name email -> ...  -- storeを参照できる
    , listUsers  = \tenantId -> ...              -- storeを参照できる
    }
```

`newInMemoryUserRepository`の中で作った`store`（`IORef`）は、関数の
外からは直接触れない。`UserRepository`のフィールドに詰める関数
（クロージャ）は、自分が定義された場所のスコープにある`store`を
「覚えたまま」値として持ち出せる。これにより「内部状態を持つが、
外から見るとただのインターフェースを実装した値」という、オブジェクト
指向で言う「カプセル化されたオブジェクト」に近いものを、クラスを使わず
に作れる。

## `resource-pool`：`Pool`・`withResource`

resource-poolライブラリ（`Data.Pool`）は次の関数群を提供している。

```haskell
newPool       :: PoolConfig a -> IO (Pool a)
defaultPoolConfig :: IO a -> (a -> IO ()) -> Double -> Int -> PoolConfig a
withResource  :: Pool a -> (a -> IO b) -> IO b
```

`postgresql-simple`の`Connection`は、1つのコネクションを複数の
リクエスト（スレッド）が同時に使い回すことを想定していない。
`resource-pool`の`Pool a`は「あらかじめ複数の`a`型の資源（ここでは
`Connection`）を用意しておき、必要なときに1つ借りて、使い終わったら
返す」という仕組みを提供する。`defaultPoolConfig`には資源の作り方
（`connectPostgreSQL connStr`）・後始末の仕方（`close`）・資源を
アイドル状態でどれだけ保持するか（秒数）・保持する最大数を渡す。
`withResource pool action`は「プールから1つ借りて`action`に渡し、
（`action`が例外を投げても）必ずプールへ返す」という一連の操作を
安全に行う。プールに空きがあれば、複数のリクエストスレッドは互いに
待たされることなく並行してDBにアクセスできる。

## `postgresql-simple`：`Query`・`FromRow`・`ToRow`・`Only`

`query`はpostgresql-simpleライブラリが提供する関数で、`src/User/Repository/Postgres.hs`
はこれと組み合わせて`instance FromRow User`を次のように定義している。

```haskell
query :: (ToRow q, FromRow r) => Connection -> Query -> q -> IO [r]

instance FromRow User where
  fromRow = User <$> field <*> field <*> field
```

`postgresql-simple`はSQLをほぼそのまま文字列（`Query`型、`Text`に
似た型）として書き、プレースホルダ（`?`）にHaskellの値を埋め込んで
実行するライブラリである。`ToRow`は「Haskellの値をSQLのパラメータ列に
変換できる」型クラス（タプルには自動的にインスタンスが用意されている）、
`FromRow`は「SQLの1行をHaskellの値に変換できる」型クラスである。
`field`は「次の1列を読む」という意味の部品で、`<$>`・`<*>`
（[0章](00-basics.md)を参照）と組み合わせて「1列目→2列目→3列目の順に読んで
`User`にまとめる」という変換を表している。列の順序はSELECT文の
列の並びと一致している必要がある。

## orphan instance

「ある型クラスのインスタンスを、その型クラスも対象の型も定義されて
いない、第三のモジュールで定義する」ことを orphan instance（孤児
インスタンス）と呼ぶ。この教材の`instance FromRow User`は、
`FromRow`（`postgresql-simple`が定義）でも`User`
（`User.Types`が定義）でもない`User.Repository.Postgres`モジュールで
定義されており、orphan instanceの一種である。GHCは orphan instance に
対して警告を出すことがある（同じ組み合わせのインスタンスが複数の
モジュールで定義されコンフリクトする事故を防ぐため）。この教材では
「DB特有の変換ロジックを、DBを知らない`User.Types`に持ち込みたくない」
という理由で意図的に許容している。

---

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 3：マルチテナント対応](04-iteration-3.md) ｜ 次へ：[Iteration 5：権限管理・エラー設計](06-iteration-5.md)
