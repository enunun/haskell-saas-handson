# Iteration 4：演習

## この章で作るもの

`POST /users`・`GET /users`のデータ保存先を、in-memoryのIORefから
PostgreSQLデータベースへ置き換える。ただし、Handler（`User.Server`）が
「データがIORefに入っているかPostgreSQLに入っているか」を知らずに済む
よう、`UserRepository`という抽象化を導入する。これにより、Handlerの
ロジックを一切変えずに保存方式だけを差し替えられることを確認する。

これはオブジェクト指向でいうDI（Dependency Injection、依存性注入）と
同じ発想である。OOPでは「インターフェース（例：`IUserRepository`）を
定義し、実装（本物のDBアクセスクラス／テスト用のモック）を実行時に
注入する」ことでテスタブルな設計を作る。Haskellにはクラスや
DIコンテナはないが、`UserRepository`という**レコード・オブ・関数**
（関数をフィールドに持つ普通のレコード型）を「インターフェース」、
`newInMemoryUserRepository`・`newPostgresUserRepository`を「実装」、
`server repo`のように関数の引数として渡すことを「注入」とみなせば、
同じことをより単純な道具（関数とレコード）だけで実現できる。

**単体テスト（`test/unit`）はin-memory実装だけを使い、実DBに一切依存
しない。結合テスト（`test/integration`）は実際に起動したPostgreSQLに
依存してよい**、というのが本章のテスト方針である。in-memory実装・
PostgreSQL実装の両方が同じ`UserRepository`という契約を満たすことを、
`test/unit/User/RepositorySpec.hs`（in-memory向け）・
`test/integration/User/RepositorySpec.hs`（PostgreSQL向け）という
ほぼ同じ内容のテストで確認する。

## 進め方

演習は4-1（Repository抽象化とDIの関係を読み解く）→4-2（in-memory実装を
仕上げる）→4-3（PostgreSQL実装を実装する）→4-4（テスト全体の確認）→4-5
（発展）という順で積み上げる。詰まった場合は
`saas-handson-solution/docs/iteration-4.md`の対応する節を参照する。
コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

## 事前準備：DBスキーマの適用

演習に入る前に、PostgreSQLに`users`テーブルを作成しておく必要がある。
本教材ではテーブル定義を`db/schema.sql`という1つのファイルに宣言的に
書き、`psqldef`（PostgreSQL用の宣言的マイグレーションツール、
devcontainerにインストール済み）でDBへ適用する。

```sql
-- db/schema.sql
CREATE TABLE users (
  id        SERIAL PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  name      TEXT NOT NULL,
  email     TEXT NOT NULL
);
```

`psqldef`は「CREATE TABLEしろ」「この列を追加しろ」という**手順**を
書くツールではない。`db/schema.sql`に書かれた**あるべき最終形**と、
今のDBの状態を比較し、差分を自動的に計算して適用する。そのため
`db/schema.sql`は「マイグレーション履歴」ではなく、そのまま
「今のテーブル定義書」として読める（常に最新のスキーマそのものが
書いてある）。

まず`--dry-run`で、何が実行されようとしているかを確認する。

```sh
PGPASSWORD=postgres psqldef -U postgres -h db saas_handson --dry-run -f db/schema.sql
```

問題なければ`--apply`で実際に適用する。

```sh
PGPASSWORD=postgres psqldef -U postgres -h db saas_handson --apply -f db/schema.sql
```

もう一度`--dry-run`を実行すると、今度は`-- Nothing is modified --`と
表示され、何も変更が必要ない（＝DBの状態が`db/schema.sql`と一致して
いる）ことが確認できる。`db/schema.sql`を変更した場合も、同じ2つの
コマンドを再実行するだけでよい。

## 演習4-1：Repository抽象化とDIの関係を読み解く

以下のファイルはすでに完成しており変更不要である。これらを読み、
下記の問いに自分の言葉で答えられるようにする（コードを書く必要はない）。

- `src/User/Repository.hs`
- `src/User/Server.hs`

```haskell
data UserRepository = UserRepository
  { createUser :: TenantId -> Text -> Text -> IO User
  , listUsers  :: TenantId -> IO [User]
  }
```

```haskell
server :: UserRepository -> Server API
server repo = createUserHandler :<|> listUsersHandler
  where
    createUserHandler authUser (CreateUserRequest reqName reqEmail) =
      liftIO (createUser repo (authTenantId authUser) reqName reqEmail)

    listUsersHandler authUser = liftIO (listUsers repo (authTenantId authUser))
```

1. OOPで「DIしやすい設計」を作るときは、具象クラスではなくインター
   フェースに依存するように書く（依存性逆転の原則）。`server`関数は
   `UserRepository`という「インターフェース」にしか依存しておらず、
   `User.Repository.InMemory`・`User.Repository.Postgres`という
   「実装」を一切importしていない。このことをコードのどこから確認
   できるか。
2. 単体テストで`newInMemoryUserRepository`を、実サーバー
   （`app/Main.hs`）で`newPostgresUserRepository`を、それぞれ`server`
   に「注入」している。OOPのDIコンテナ（Spring等）がXML設定やアノテー
   ションで行っていることを、Haskellでは何がその役割を果たしているか。
3. `UserRepository`は型クラス（`class`）ではなくレコード型として定義
   されている。型クラスで同じことをしようとした場合と比べて、
   「実行時にどちらの実装を使うか選べる」という性質にどう違いが出るか
   考えてみる。

## 演習4-2：in-memory実装を仕上げる

`src/User/Repository/InMemory.hs`の`createUserImpl`・`listUsersImpl`を
実装する（Iteration 1・3から未着手の場合はこの演習でまとめて実装する）。

```haskell
createUserImpl :: IORef (Int, Map TenantId [User]) -> TenantId -> Text -> Text -> IO User
createUserImpl _store _tenantId _reqName _reqEmail = error "TODO: Iteration 1/3/4で実装する"

listUsersImpl :: IORef (Int, Map TenantId [User]) -> TenantId -> IO [User]
listUsersImpl _store _tenantId = error "TODO: Iteration 1/3/4で実装する"
```

`IORef`の中身は`(次に採番するグローバルid, テナントIDごとの登録済み
ユーザー一覧)`という組である。Iteration 3までは「次に採番するid」も
テナントごとに独立していたが、Iteration 4ではPostgreSQL実装（演習4-3）
が採番をDB全体で共有される`SERIAL`に委ねることに合わせ、in-memory実装
側もテナントを跨いだグローバルな連番に変更している。

- `Data.Map.Strict.findWithDefault []`で、該当テナントの登録済み
  ユーザー一覧を取り出す（未登録のテナントなら空リスト）。
- `Data.IORef.atomicModifyIORef'`で`(nextId, tenants)`全体を読み・
  書きし、`nextId`は常に1つ進め、該当テナントのバケットだけを
  `Data.Map.Strict.insert`で更新する。

```sh
cabal test saas-handson --test-options='--match "in-memory"'
```

を実行し、`test/unit/User/RepositorySpec.hs`（6件）がすべてGREENに
なることを確認する。このテストは実DBを一切必要としない。

## 演習4-3：PostgreSQL実装を実装する

`src/User/Repository/Postgres.hs`の`createUserImpl`・`listUsersImpl`を
実装する。`FromRow User`インスタンス・コネクションプール
（`resource-pool`）の管理はすでに用意されている。テーブルの作成は
アプリケーションの責務ではない（「事前準備」で`psqldef`を使って別途
行う）。

```haskell
createUserImpl :: Pool Connection -> TenantId -> Text -> Text -> IO User
createUserImpl _pool _tenantId _reqName _reqEmail = error "TODO: Iteration 4で実装する"

listUsersImpl :: Pool Connection -> TenantId -> IO [User]
listUsersImpl _pool _tenantId = error "TODO: Iteration 4で実装する"
```

- テーブル定義（`newPostgresUserRepository`を参照）は`id`列を
  `SERIAL PRIMARY KEY`にしてある。`SERIAL`はPostgreSQLが自動的に連番を
  払い出す仕組みで、**「次のidは何か」をアプリケーション側で計算する
  必要が一切なくなる**。
- `createUserImpl`は`"INSERT INTO users (tenant_id, name, email) VALUES
  (?, ?, ?) RETURNING id"`を`query`で実行するだけでよい。`RETURNING
  id`により、INSERTで払い出された（DBが決めた）idをその場で受け取れる。
  `[Only newId] <- query ...`のように1行1列の結果を取り出し、
  `User newId reqName reqEmail`を返す。
- なぜこれで採番の競合状態（複数リクエストが同時に来ても同じidが
  重複して払い出されない）が起きないのか考えてみる。Iteration 3までの
  in-memory実装（`atomicModifyIORef'`）・SQLite案
  （`withImmediateTransaction`＋`SELECT MAX(id)+1`、Iteration 4の
  当初の設計案）と比べて、アプリケーション側のコードにロック・
  トランザクション制御が一切登場しないことに注目する。「自動発番の
  責務をDB側に寄せる」というのはこのことを指す。
- `listUsersImpl`は`"SELECT id, name, email FROM users WHERE tenant_id
  = ? ORDER BY id"`を`query`で実行するだけでよい（`FromRow User`
  インスタンスがすでに用意されているため、結果は自動的に`[User]`に
  変換される）。

この演習は実DBに依存するテスト（`test/integration/User/RepositorySpec.hs`）
で確認するため、devcontainerのdbサービスが起動していること、
「事前準備」でスキーマを適用済みであることを確認する。

```sh
cabal test saas-handson --test-options='--match "PostgreSQL"'
```

上記コマンドは`test:integration`スイートを対象にする必要がある
（`cabal test saas-handson:test:integration --test-options='--match
"PostgreSQL"'`のように明示してもよい）。dbサービスはdevcontainerを
開いた時点ですでに起動しているため、追加の準備は不要である。

## 演習4-4：テストをすべてGREENにする

```sh
cabal test saas-handson:test:unit
```

を実行し、単体テストがすべてGREENになっていることを確認する。単体
テストは実DBに一切依存しないため、devcontainerの外でも（dbサービスが
落ちていても）常にGREEN/REDの判定ができる。

```sh
cabal test saas-handson:test:integration
```

を実行し、結合テストがすべてGREENになっていることを確認する。
`test/integration/User/RepositorySpec.hs`（PostgreSQL実装の契約テスト、
6件）・`test/integration/User/UserSpec.hs`（HTTP層を含むend-to-end
テスト、8件）がある。これらはdbサービスへの接続を必要とするため、
devcontainerの外や、dbサービスが起動していない環境では失敗する
（`libpq: failed (could not translate host name "db" to address ...)`
のようなエラーになる）。これは実装のバグではなく、結合テストが
「実DBに依存してよい」というテスト方針どおりに動いていることを意味
する。「事前準備」でスキーマを適用し忘れている場合は、代わりに
`relation "users" does not exist`のようなエラーになる。

## 演習4-5（発展）：実サーバーでの永続化確認・設計の一般化

1. `cabal run saas-handson`でサーバーを起動し、`POST /users`で
   ユーザーを作成したあと、サーバーを一度Ctrl+Cで止めて再起動し、
   `GET /users`で先ほど作成したユーザーがまだ存在することを確認する
   （in-memoryだった頃はサーバーを再起動するとデータが消えていた）。
2. devcontainerの外から`psql`等でPostgreSQL（`localhost:5433`、
   `docker-compose.yml`参照）に直接繋ぎ、`SELECT * FROM users;`で
   テーブルの中身を確認してみる。`id`列がテナントを跨いでグローバルに
   連番になっていることが確認できる。
3. `UserRepository`と同じパターン（Handleパターンによる抽象化）を
   `AuthenticatedUser`の検証（`Auth.Server`）にも適用するとしたら、
   どのような形になるか設計してみる。すでに`JWKStore`は似た形をして
   いる（`newJWKStore`・`mkJWKStore`という2つのコンストラクタを持つ）
   ことに注目する。
4. 本章では単体テストと結合テストで「同じ契約を異なる実装が満たして
   いるか」を確認する`repositoryContractSpec`という関数を、
   `test/unit`・`test/integration`それぞれに重複して定義した。この
   重複を解消する（共有のテストヘルパーモジュールを作る）としたら、
   cabalファイルにどのような変更が必要か考えてみる（実装は必須では
   ない）。

### 実装時に必要になるLANGUAGE拡張・依存パッケージ

| 用途 | 拡張／依存 |
|---|---|
| PostgreSQLへのアクセス全般（`connectPostgreSQL`・`query`・`execute`等） | `postgresql-simple`パッケージ |
| コネクションプール（`Pool`・`withResource`） | `resource-pool`パッケージ |
| SQL文字列リテラルの複数行結合 | `{-# LANGUAGE OverloadedStrings #-}`（`Query`型が`IsString`のインスタンスであるため） |
| `postgresql-simple`のビルド自体に必要なCライブラリ | `libpq-dev`（`.devcontainer/Dockerfile`にすでに追加済み。ローカル環境で自分でセットアップする場合は`apt install libpq-dev`等が必要） |
| DBスキーマの宣言的な適用 | `psqldef`（`.devcontainer/Dockerfile`にすでに追加済み。Haskellのパッケージではなく単体のCLIツール） |

`cabal build`・`cabal test`で「Could not load module」のようなエラーが
出た場合は、上記のいずれかが`.cabal`の`build-depends`に不足している
可能性が高い。「`configure: error: Library requirements (PostgreSQL)
not met`」のようなエラーが出た場合は、`libpq-dev`（またはそれに相当する
パッケージ）がインストールされていない可能性が高い。
