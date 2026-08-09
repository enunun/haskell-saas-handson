# Iteration 4：解説

このドキュメントは`saas-handson/docs/iteration-4.md`の演習問題に対応する
解答解説である。見出しの番号（4-1〜4-5）は演習側と対応している。

## 設計判断：PostgreSQL・DI・テスト方針・DB側での自動発番・宣言的マイグレーション

ROADMAPのIteration 4は「in-memoryストアからDBへの置き換え、Repository
抽象化」を目的とする。本教材では以下の5点を軸に設計した。

1. **DBはPostgreSQL（`postgresql-simple`）を使う。** SQLiteではなく
   実務のtoB SaaSでよく使われるPostgreSQLを選ぶことで、コネクション
   プール・`SERIAL`による自動採番・実DBに依存する結合テストといった、
   より実務に近いテーマを扱えるようにした。
2. **単体テストはin-memory実装だけを使い、実DBには一切依存しない。
   結合テストは実際に起動したPostgreSQLに依存してよい。** これは
   「テストピラミッド」の考え方に沿ったテスト方針である。単体テストは
   高速・決定的・環境非依存であることを最優先し、実際のSQL・
   ネットワーク・DBサーバーの起動状態に依存するテストは結合テストに
   閉じ込める。
3. **Repository抽象化はDI（Dependency Injection）のHaskellでの実現
   方法として位置付ける。** `UserRepository`という「インターフェース」
   を`Server`層が要求し、実行時に`newInMemoryUserRepository`（テスト・
   開発）または`newPostgresUserRepository`（本番相当）のどちらかを
   「注入」する。OOPのDIコンテナに相当する特別な仕組みは要らず、
   関数の引数として渡すだけでよい。
4. **自動発番の責務をDB側（PostgreSQLの`SERIAL`）に寄せる。** Iteration
   1〜3のin-memory実装、およびIteration 4の当初案（SQLite）は
   「次のidをアプリケーション側が計算し、競合しないようロックする」
   という責務を負っていた。PostgreSQLの`SERIAL`と`INSERT ... RETURNING
   id`を使うと、採番の原子性はDBが保証してくれるため、アプリケーション
   側の並行制御コードが不要になる。
5. **スキーマの管理は宣言的マイグレーションツール（`psqldef`）に任せ、
   アプリケーションコードから切り離す。** 当初`newPostgresUserRepository`
   の中で`CREATE TABLE IF NOT EXISTS`をその場で実行していたが、これは
   「今のスキーマが何か」を知る手段がアプリケーションコードと
   （将来増えるはずの）マイグレーション履歴の2箇所に分散してしまう
   手続き的な仕組みだった。`db/schema.sql`に「あるべきテーブル定義」を
   宣言的に書き、`psqldef`にDBの現在の状態との差分を計算・適用させる
   ことで、`db/schema.sql`をそのまま「常に最新のテーブル定義書」として
   扱えるようにした。

この設計の帰結として、idの採番方式がIteration 3までの「テナントごとに
1から連番」から「テナントを跨いだグローバルな連番」に変わった。これは
DBの`SERIAL`が単一のテーブルに対して単一の連番を払い出す（PostgreSQLは
`(tenant_id, id)`のような複合キーに対する自動採番を標準機能としては
持たない）という制約に合わせたものであり、in-memory実装もこれに合わせて
挙動を変更した（`test/unit/User/RepositorySpec.hs`・
`test/unit/User/UserSpec.hs`の該当テストを参照）。

## 事前準備の解説：DBスキーマの適用

```sql
-- db/schema.sql
CREATE TABLE users (
  id        SERIAL PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  name      TEXT NOT NULL,
  email     TEXT NOT NULL
);
```

`psqldef`（[sqldef/sqldef](https://github.com/sqldef/sqldef)）は
PostgreSQL・MySQL・SQLite等向けの宣言的マイグレーションツール群
（`psqldef`・`mysqldef`・`sqlite3def`等）の1つである。「マイグレーション
ファイルを順番に適用する」という手続き的な仕組み（Flyway、
Railsのマイグレーション、あるいはHaskellの`postgresql-simple-migration`
等）は、`0001_create_users.sql`・`0002_add_tenant_id.sql`のように変更
履歴を積み重ねる方式のため、「今のテーブル定義は結局どうなっているか」
を知るには全履歴を頭の中で再生する必要がある。`psqldef`はこれと異なり、
`db/schema.sql`に**最終的にあるべきスキーマ**を1つのCREATE TABLE文と
して書き、実行中のDBの現在の状態と比較して差分（ALTER TABLE等）を
自動的に計算・適用する。そのため`db/schema.sql`は常に「今の正しい
テーブル定義」を表しており、マイグレーション手段であると同時にテーブル
定義書を兼ねる。

```sh
PGPASSWORD=postgres psqldef -U postgres -h db saas_handson --dry-run -f db/schema.sql
PGPASSWORD=postgres psqldef -U postgres -h db saas_handson --apply -f db/schema.sql
```

`--dry-run`は実際にDDLを実行せず、何が実行されようとしているかだけを
表示する（`terraform plan`に近い）。`--apply`で初めて実際にDDLを適用
する（`terraform apply`に近い）。適用済みの状態で再度`--dry-run`する
と`-- Nothing is modified --`と表示され、冪等であることが確認できる。

`newPostgresUserRepository`から`CREATE TABLE IF NOT EXISTS`を削除した
のはこのためである。アプリケーションの起動時に暗黙にDDLを実行する
（しかもテーブルが存在する前提のコードとテーブルを作るコードが同じ
ファイルに同居する）のではなく、スキーマの管理を独立した明示的な
ステップに切り出すことで、「今のスキーマは`db/schema.sql`を見れば
分かる」という状態を作っている。

## 演習4-1の解説：Repository抽象化とDIの関係を読み解く

### `server`は`UserRepository`という「インターフェース」にしか依存しない

```haskell
server :: UserRepository -> Server API
server repo = createUserHandler :<|> listUsersHandler
  where
    createUserHandler authUser (CreateUserRequest reqName reqEmail) =
      liftIO (createUser repo (authTenantId authUser) reqName reqEmail)

    listUsersHandler authUser = liftIO (listUsers repo (authTenantId authUser))
```

`src/User/Server.hs`のimport文には`User.Repository`（インターフェース）
はあるが、`User.Repository.InMemory`・`User.Repository.Postgres`
（実装）は一切登場しない。OOPで言えば「具象クラスを直接importせず、
インターフェース経由でしか依存しない」という依存性逆転の原則（DIP）を、
Haskellのモジュールシステムのレベルでそのまま体現している。`server`
関数のコードを読むだけで、「これはIORefなのかDBなのか」を一切気にせず
書かれていることが分かる。

### 「注入」はただの関数適用である

OOPのDIコンテナ（Spring、.NETのDIコンテナ等）は、XML設定やアノテーション
を解釈して「どの実装をどこに渡すか」を実行時に解決する、専用の仕組みで
ある。Haskellでは`server`が単なる関数であるため、「注入」は
`server repo`という普通の関数適用に他ならない。

- `test/unit/User/UserSpec.hs`：`repo <- newInMemoryUserRepository`
  してから`server repo`。
- `app/Main.hs`：`repo <- newPostgresUserRepository dbConnStr`してから
  最終的に`mkServer repo`（`Server.hs`経由）。

「実行時にどちらの実装を使うかをどう決めるか」という関心事は、
`main`関数（あるいはテストの`spec`関数）という、依存関係の組み立てを
行う場所に集約されている。これは「コンポジションルート
（Composition Root）」と呼ばれる、DIのベストプラクティスの1つでもある。
Haskellではこれが特別なフレームワークの機能ではなく、単に「`main`は
必要な値を作ってから、それを引数として渡す」という関数型言語における
ごく普通のプログラムの構造として自然に実現される。

### 型クラスではなくレコード型を選んだ理由

（Iteration 4当初の「設計判断」を踏襲）1つのプロセス内で「どの実装を
使うか」を型レベルで静的に選ぶ必要がなく、`newInMemoryUserRepository`・
`newPostgresUserRepository`のどちらも`IO UserRepository`という同じ型を
持つ値を実行時に選んで渡せば十分だからである。型クラスにすると、
`Server`型や`mkServer`の型シグネチャに実装を表す型変数を持ち込むことに
なり、Servantの`Server API`という具体型と相性が悪くなる。

## 演習4-2の解説：in-memory実装を仕上げる

```haskell
newInMemoryUserRepository :: IO UserRepository
newInMemoryUserRepository = do
  store <- newIORef (1, Map.empty)
  pure UserRepository
    { createUser = createUserImpl store
    , listUsers = listUsersImpl store
    }

createUserImpl :: IORef (Int, Map TenantId [User]) -> TenantId -> Text -> Text -> IO User
createUserImpl store tenantId reqName reqEmail =
  atomicModifyIORef' store $ \(nextId, tenants) ->
    let users = Map.findWithDefault [] tenantId tenants
        newUser = User nextId reqName reqEmail
        tenants' = Map.insert tenantId (users ++ [newUser]) tenants
    in ((nextId + 1, tenants'), newUser)

listUsersImpl :: IORef (Int, Map TenantId [User]) -> TenantId -> IO [User]
listUsersImpl store tenantId =
  Map.findWithDefault [] tenantId . snd <$> readIORef store
```

Iteration 3の`Store`は`Map TenantId (Int, [User])`（採番カウンタも
テナントごと）だったが、Iteration 4では`(Int, Map TenantId [User])`
（採番カウンタはグローバルに1つ、テナントごとに持つのはユーザー一覧の
み）に変えた。`atomicModifyIORef'`で`(nextId, tenants)`という組全体を
アトミックに読み書きする点はIteration 1〜3と変わらない。

## 演習4-3の解説：PostgreSQL実装を実装する

```haskell
createUserImpl :: Pool Connection -> TenantId -> Text -> Text -> IO User
createUserImpl pool tenantId reqName reqEmail =
  withResource pool $ \conn -> do
    [Only newId] <- query conn
      "INSERT INTO users (tenant_id, name, email) VALUES (?, ?, ?) RETURNING id"
      (unTenantId tenantId, reqName, reqEmail)
    pure (User newId reqName reqEmail)

listUsersImpl :: Pool Connection -> TenantId -> IO [User]
listUsersImpl pool tenantId =
  withResource pool $ \conn ->
    query conn
      "SELECT id, name, email FROM users WHERE tenant_id = ? ORDER BY id"
      (Only (unTenantId tenantId))
```

### `SERIAL` + `RETURNING id`：自動発番をDBに委ねる

テーブル定義（`db/schema.sql`）は`id SERIAL PRIMARY KEY`となっている。`SERIAL`はPostgreSQL内部で暗黙のシーケンス
（`users_id_seq`）を作り、行を挿入するたびに次の値を自動的に払い出す。
複数のコネクションから同時に`INSERT`されても、シーケンスからの値の
取得はPostgreSQLエンジン内部でアトミックに行われるため、
アプリケーション側で「読んでから書く」という手順を明示的にトランザク
ションで保護する必要がない。`RETURNING id`句を使うことで、
「INSERTする」と「払い出されたidを知る」を1回のSQL文・1回のDB往復で
完結できる。

これをIteration 4の当初案（SQLiteでの`SELECT MAX(id)+1`＋
`withImmediateTransaction`）と比較すると、アプリケーション側のコードから
明示的なロック・トランザクション制御が完全に消えている。「自動発番の
責務をDB側に寄せる」というのは、まさにこの変化を指している。DBの機能
（この場合はシーケンス）を信頼することで、アプリケーションコードが
関心を持つべき範囲を「何を保存したいか」だけに絞れる。

### コネクションプール（`Pool Connection`）

postgresql-simpleの`Connection`もsqlite-simpleと同様、複数スレッドから
の同時利用を想定していない。前バージョン（SQLite案）では
`MVar Connection`で単一のコネクションへのアクセスを直列化したが、
PostgreSQLサーバー自体は複数のコネクションからの同時アクセスを安全に
処理できるため、`resource-pool`の`Pool Connection`を使い、各リクエスト
が（プールに空きがあれば）別々のコネクションを使って本当に並行して
DBにアクセスできるようにした。`withResource pool $ \conn -> ...`は
プールからコネクションを1つ借り、アクションが終わったら（例外が起きて
も）返却する。

## 演習4-4の解説：テストをすべてGREENにする

### テストピラミッドとしてのunit / integration

```
test/unit/User/RepositorySpec.hs         -- in-memory実装のみ、実DB不要
test/integration/User/RepositorySpec.hs  -- PostgreSQL実装、dbサービス必須
```

両ファイルは`repositoryContractSpec :: IO UserRepository -> Spec`という
同じ形の関数を持ち、テスト本体（6件）も文字どおり同一である。異なるのは
`newRepo`に何を渡すか（`newInMemoryUserRepository` vs
`resetDb >> newPostgresUserRepository testConnStr`）だけである。この
構成により「同じ契約を異なる実装が満たしている」ことをコードで保証
しつつ、単体テストは実DBに一切触れない（`cabal test
saas-handson-solution:test:unit`はdbサービスが起動していなくても常に
実行できる）という制約を両立している。

### 実DBに対するテストの状態リセット

```haskell
resetDb :: IO ()
resetDb = do
  conn <- connectPostgreSQL testConnStr
  _ <- execute_ conn "TRUNCATE TABLE users RESTART IDENTITY"
  close conn
```

`":memory:"`のSQLiteやIORefは、テストケースごとに新しく作り直すだけで
自動的にまっさらな状態から始められた。実際に起動し続けているPostgreSQL
サーバーに対してはこれができないため、明示的に`TRUNCATE TABLE users
RESTART IDENTITY`でテーブルを空にし、`SERIAL`のシーケンスも1から
振り直している（`RESTART IDENTITY`を付けないと、シーケンスの値は
`TRUNCATE`後も進んだままになり、`id`が1から始まることを期待するテスト
のアサーションが崩れる）。

`test/integration/User/UserSpec.hs`では、この`resetDb`をhspec-waiの
`with`に渡す`IO Application`アクションの一部として組み込んでいる
（`let app = resetDb >> pure (mkApp ... repo)`）。hspec-waiの`with`は
このアクションをテストケースごとに再評価するため、結果として
「テストケースごとにテーブルが空の状態から始まる」という、これまでの
`newStore`・`":memory:"`と同じ体験を、実DBに対しても実現している。

## 演習4-5の解説（発展）：実サーバーでの永続化確認・設計の一般化

### 永続化の確認

`app/Main.hs`は`newPostgresUserRepository dbConnStr`
（`dbConnStr`は`host=db port=5432 dbname=saas_handson user=postgres
password=postgres`）で起動する。`db`サービスはコンテナのボリューム上に
データファイルを保持しているため、アプリケーションプロセス（`cabal
run`）を再起動してもデータは失われない。これが「永続化」の意味であり、
Iteration 1〜3のin-memory実装では実現できなかった性質である。

### DI・Handleパターンの他箇所への適用

`Auth.Server`の`JWKStore`は、実は`UserRepository`と同じ設計思想
（`newJWKStore`という「本番用のコンストラクタ」と`mkJWKStore`という
「テスト用の直接構築」という2つの入口を持つ）をすでに持っている
（Iteration 2）。`UserRepository`との違いは、`JWKStore`が単一の
`newtype`でラップされた値（`JWKSet`）そのものであるのに対し、
`UserRepository`は複数の操作（`createUser`・`listUsers`）をまとめた
レコードになっている点である。「外部リソースへのアクセスをコンストラ
クタ関数の背後に隠し、テスト用の代替コンストラクタも用意する」という
パターンは、本教材を通じて繰り返し使われている設計上のモチーフである。

### テストヘルパーの重複

`repositoryContractSpec`を`test/unit`・`test/integration`の両方に
コピーしているのは、cabalの`test-suite`スタンザ同士がデフォルトでは
コードを共有できないためである。厳密に重複を排除するには、共有コードを
`library`スタンザ（あるいは`common`スタンザやinternal library）に切り
出し、両方の`test-suite`から`build-depends`で参照する必要がある。
本教材ではテストコード相互の依存関係を増やすよりも、それぞれの
test-suiteが自己完結している方が読みやすいと判断し、あえて重複を許容
した（同じ理由で、`saas-handson`・`saas-handson-solution`という2つの
`.cabal`パッケージ間でもコードは共有していない）。
