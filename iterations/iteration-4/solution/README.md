# saas-handson-solution-iteration4（解答例）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 4の解答例
プロジェクトである。

## 現在の状態

ユーザーデータの永続化方式がPostgreSQLに置き換わっている。
`UserRepository`インターフェースでデータアクセスを抽象化し、
単体テストはin-memory実装、結合テストはPostgreSQL実装を使う。

## 事前準備

結合テスト・サーバー起動には`db`サービス（PostgreSQL）が必要である。
初回は`db/schema.sql`を`psqldef`で適用しておく。

```sh
PGPASSWORD=postgres psqldef -U postgres -h db saas_handson --apply -f db/schema.sql
```

## 実行方法

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト（実DB・外部サービスに一切依存しない）
cabal test saas-handson-solution-iteration4:test:unit

# 結合テスト（dbサービスに接続する）
cabal test saas-handson-solution-iteration4:test:integration

# サーバーを起動する（mock-auth・dbサービスに接続する）
cabal run saas-handson-solution-iteration4
```

## ディレクトリ構成

```
src/User/Repository.hs             UserRepositoryインターフェース（Handleパターン）
src/User/Repository/InMemory.hs    in-memory実装（単体テスト用）
src/User/Repository/Postgres.hs    PostgreSQL実装（本番・結合テスト用）
src/User/Server.hs                 UserRepositoryを受け取るハンドラ
src/Api.hs, Server.hs              機能ごとのAPI型・server値を合成するcombinator
app/Main.hs                        エントリポイント
test/                              単体テストはInMemory、結合テストはPostgresを使う
docs/iteration-4.md                設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-4.md`

対応する演習用プロジェクトは`../exercise`である。
