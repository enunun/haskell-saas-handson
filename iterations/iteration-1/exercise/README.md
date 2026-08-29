# saas-handson-iteration1（演習）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 1の演習用
プロジェクトである。

## このIterationで作るもの

ユーザーリソースのCRUD（`POST /users`・`GET /users`・
`GET /users/{id}`）をメモリ内のストアで構築し、機能が2つ（Health,
User）になったタイミングで、機能ごとにディレクトリを分けるVertical
Slice構成へリファクタリングする。

## 進め方

1. `docs/iteration-1.md`を読み、演習1-1から順に取り組む。
2. `cabal test saas-handson-iteration1:test:unit saas-handson-iteration1:test:integration`
   でテストの状態を確認しながら進める。
3. 最後にあるテストがGREENになることを確認する。
4. 行き詰まった場合は`../solution/`の同名ファイル・
   `../solution/docs/iteration-1.md`を参照する。

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト
cabal test saas-handson-iteration1:test:unit

# 結合テスト
cabal test saas-handson-iteration1:test:integration

# サーバーを起動する
cabal run saas-handson-iteration1
# 別ターミナルから
curl http://localhost:8080/health
curl -X POST http://localhost:8080/users \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com"}'
curl http://localhost:8080/users
```

## ディレクトリ構成

演習1-8のリファクタリングを終えるまでは、`src/Api.hs`・`Server.hs`・
`Types.hs`がHealthの実装を直接持つ技術層別構成のままである。

```
src/Api.hs、Server.hs、Types.hs   Healthの実装（変更不要。演習1-8でHealth/へ移す）
src/User/Api.hs                   UserのAPI型（変更不要）
src/User/Types.hs                 User, CreateUserRequest（変更不要）
src/User/Store.hs                 メモリ内ストア（変更不要）
src/User/Server.hs                Userハンドラ実装（3つともTODO）
app/Main.hs                       エントリポイント
test/unit/                        単体テスト（Health分は既存。User分は演習1-2〜1-6で1つずつ自作する）
test/integration/                 結合テスト（Health分は既存。User分は演習1-7で自作する）
docs/iteration-1.md               演習手順
```

## 資料

- 演習手順：`docs/iteration-1.md`
- 行き詰まった場合の解答例：`../solution/`
