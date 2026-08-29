# Iteration 4：演習

## この章で作るもの

ユーザーデータの永続化方式を、メモリ内のストアからPostgreSQLへ置き換える。
`UserRepository`というインターフェース（Handleパターン）でデータアクセスを
抽象化し、in-memory実装・PostgreSQL実装の両方を用意する。ハンドラ
（`User.Server`）はどちらの実装が使われているかを一切知らない状態を
保つ。idの採番はPostgreSQLの`SERIAL`に完全に委ね、アプリケーション側の
採番ロジック・ロック制御を不要にする。

`src/User/Repository.hs`（インターフェース）・
`src/User/Repository/Postgres.hs`（PostgreSQL実装）はすでに完成している
（postgresql-simple・resource-poolの使い方自体は本教材の主題ではない
ため、既存の実装を読んで理解する形にしている）。この章の演習は、
in-memory実装を完成させ、既存のコード・テストをUserRepository経由に
切り替えることが中心になる。

## 事前準備

結合テストの実行・サーバー起動には、devcontainerのdocker composeで
一緒に起動する`db`サービス（PostgreSQL）が必要である。初回は
`db/schema.sql`を`psqldef`で適用しておく。

```sh
PGPASSWORD=postgres psqldef -U postgres -h db saas_handson --apply -f db/schema.sql
```

## 進め方

演習は4-1から順に取り組む。詰まった場合は`../solution/docs/iteration-4.md`
の対応する節を読む。コマンドはリポジトリルート（`cabal.project`のある
場所）から実行する。

## 演習4-1：Repository層を読み解く

`src/User/Repository.hs`・`src/User/Repository/Postgres.hs`を読み、
以下を自分の言葉で説明できるようにする（コードを書く必要はない）。

1. `UserRepository`は型クラスではなく、関数を3つ持つレコード
   （Handleパターン）として定義されている。型クラスにしなかった理由を、
   `newPostgresUserRepository`が接続プールをクロージャに閉じ込めて
   いる様子から考える。
2. `createUserImpl`は`INSERT INTO users (...) VALUES (...) RETURNING id`
   という1文のSQLだけで採番と登録を行っている。`src/User/Store.hs`
   （Iteration 3）の`atomicModifyIORef'`による採番と比べて、
   アプリケーション側で意識する必要がなくなったものは何か。
3. `Pool Connection`・`withResource`は何のためにあるか。
   `postgresql-simple`の`Connection`を複数のリクエストが同時に使い
   回した場合に何が起こりうるかから考える。
4. `instance FromRow User where fromRow = ...`は`User.Repository.Postgres`
   モジュールの中に置かれている（`User.Types`には置いていない）。
   なぜこの場所に置くのが適切か。

## 演習4-2：in-memory実装を完成させる（Green）

`src/User/Repository/InMemory.hs`の3つのフィールドは`error "TODO: ..."`
のままである。`src/User/Store.hs`（Iteration 3で書いたもの）とほぼ同じ
ロジックを、`UserRepository`のフィールドとして実装する。

## 演習4-3：既存のコードをUserRepositoryへ切り替える

1. `src/User/Server.hs`を、`User.Store`ではなく`User.Repository`の
   `UserRepository`を受け取る形に書き換える（引数名は`store`から`repo`
   に変えるとよい）。ハンドラ本体のロジック自体はほとんど変わらない
   ことを確認する。
2. トップレベルの`src/Server.hs`・`app/Main.hs`を、`UserRepository`
   （本番は`newPostgresUserRepository`）を組み立てて渡す形に書き換える。
3. `test/unit/User/UserSpec.hs`を、`User.Store.newStore`ではなく
   `User.Repository.InMemory.newInMemoryUserRepository`を使う形に
   書き換える。

```sh
cabal test saas-handson-iteration4:test:unit
```

を実行し、GREENになることを確認する。

4. 不要になった`src/User/Store.hs`を削除し、
   `saas-handson-iteration4.cabal`の`exposed-modules`から`User.Store`を
   取り除く。

## 演習4-4：結合テストをPostgreSQLに切り替える（Red→Green）

`test/integration/User/UserSpec.hs`を、実際にPostgreSQLへ接続する形に
書き換える。

1. `Auth.Server.mkJWKStore`でテスト用の鍵を注入する部分はIteration 3と
   変わらない。変わるのは、Applicationを組み立てる際に
   `User.Repository.Postgres.newPostgresUserRepository`を使う点である
   （接続文字列は`app/Main.hs`と同じものを使う）。
2. 実DBのテーブルはテストをまたいで共有される状態であるため、各テストの
   前に空にしておく必要がある。`Database.PostgreSQL.Simple`の
   `execute_`で`"TRUNCATE TABLE users RESTART IDENTITY"`を実行する
   ヘルパーを、Applicationを組み立てる関数の先頭で呼び出す。

```sh
cabal test saas-handson-iteration4:test:integration
```

を実行し、GREENになることを確認する（`db`サービスが起動している必要が
ある）。

## 演習4-5：単体テスト・結合テストへの影響を考える

1. 単体テストは`User.Repository.InMemory`を使い続けている。結合テストは
   `User.Repository.Postgres`に切り替えた。両方とも`User.Repository`と
   いう同じインターフェースを実装しているからこそ、`User.Server`の
   コードは一切変更せずに済んだ。この「同じインターフェースの複数実装を
   テストと本番で使い分ける」という設計のメリットを、Iteration 0〜3の
   `Health`・`Auth`と比べて説明する。
2. 結合テストに追加した「各テストの前にテーブルを空にする」処理は、
   Iteration 0〜3の結合テスト（in-memoryのみ）にはなかったものである。
   なぜ実DBを使う場合にだけこれが必要になるか説明する。

## 演習4-6（発展）：疎通確認

```sh
cabal run saas-handson-iteration4
```

でサーバーを起動し、`docs/iteration-3.md`の疎通確認と同じ手順でユーザーを
作成する。サーバーを再起動しても、作成したユーザーが失われずに残って
いることを確認する（メモリ内ストアとの違い）。
