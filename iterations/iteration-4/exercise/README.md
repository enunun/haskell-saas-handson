# saas-handson-iteration4（演習）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 4の演習用
プロジェクトである。

## このIterationで作るもの

ユーザーデータの永続化方式を、メモリ内のストアからPostgreSQLへ
置き換える。`UserRepository`インターフェースでデータアクセスを抽象化
し、in-memory実装・PostgreSQL実装の両方を用意する。

## 事前準備

結合テスト・サーバー起動には`db`サービス（PostgreSQL）が必要である。
初回は`db/schema.sql`を`psqldef`で適用しておく。

```sh
PGPASSWORD=postgres psqldef -U postgres -h db saas_handson --apply -f db/schema.sql
```

## 進め方

1. `docs/iteration-4.md`を読み、演習4-1から順に取り組む。
2. `cabal test saas-handson-iteration4:test:unit`（実DB不要）・
   `cabal test saas-handson-iteration4:test:integration`（`db`サービス
   が必要）でテストの状態を確認しながら進める。
3. 最後にあるテストがGREENになることを確認する。
4. 行き詰まった場合は`../solution/`の同名ファイル・
   `../solution/docs/iteration-4.md`を参照する。

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト（実DB・外部サービスに一切依存しない）
cabal test saas-handson-iteration4:test:unit

# 結合テスト（dbサービスに接続する）
cabal test saas-handson-iteration4:test:integration

# サーバーを起動する（mock-auth・dbサービスに接続する）
cabal run saas-handson-iteration4
```

## ディレクトリ構成

```
src/User/Repository.hs             UserRepositoryインターフェース（完成済み）
src/User/Repository/Postgres.hs    PostgreSQL実装（完成済み。読んで理解する）
src/User/Repository/InMemory.hs    in-memory実装（3つのフィールドがTODO）
src/User/Store.hs                  Iteration 3までの実装（演習4-3で削除する）
src/User/Server.hs                 UserRepository経由に切り替えるのが演習
src/Server.hs, app/Main.hs         UserRepositoryの組み立て・配線が演習
test/                              UserRepository経由へのテスト書き換えが演習
docs/iteration-4.md                演習手順
```

## 資料

- 演習手順：`docs/iteration-4.md`
- 行き詰まった場合の解答例：`../solution/`
