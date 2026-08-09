# Iteration 4：永続化層の導入

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 3：マルチテナント対応](04-iteration-3.md)

## Handleパターン（DI）とレコード・オブ・関数

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

## `MVar`

```haskell
newMVar   :: a -> IO (MVar a)
withMVar  :: MVar a -> (a -> IO b) -> IO b
```

`MVar a`は「中身が空か、`a`型の値が1つ入っているかのどちらかの箱」で
あり、Haskellにおける相互排他ロック（mutex）の基本的な道具である。
`withMVar`は「箱から値を取り出し、渡した関数に使わせ、（例外が起きても）
必ず値を箱へ返す」という一連の操作を安全に行う。複数のスレッドが
同時に`withMVar`しようとすると、先に取り出した側が値を返すまで、
後から来た側は待たされる（＝同時に2つのスレッドが中身を触ることは
ない）。この教材ではDBコネクションプールの排他制御に使っている。

## `postgresql-simple`：`Query`・`FromRow`・`ToRow`・`Only`

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
