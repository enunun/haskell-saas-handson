# saas-handson-solution-iteration1（解答例）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 1の解答例
プロジェクトである。

## 現在の状態

ユーザーリソースのCRUD（`POST /users`・`GET /users`・
`GET /users/{id}`）がメモリ内のストアで完成し、機能ごとに
ディレクトリを分けるVertical Slice構成（`src/Health/`・`src/User/`）に
なっている。単体テスト・結合テストともにGREENである。

## 実行方法

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト
cabal test saas-handson-solution-iteration1:test:unit

# 結合テスト
cabal test saas-handson-solution-iteration1:test:integration

# サーバーを起動する
cabal run saas-handson-solution-iteration1
# 別ターミナルから
curl http://localhost:8080/health
curl -X POST http://localhost:8080/users \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com"}'
curl http://localhost:8080/users
curl http://localhost:8080/users/1
```

## ディレクトリ構成

```
src/Api.hs, Server.hs             機能ごとのAPI型・server値を:<|>で合成するcombinator
src/Health/Api.hs, Server.hs, Types.hs   ヘルスチェック機能
src/User/Api.hs                   UserのAPI型
src/User/Types.hs                 User, CreateUserRequest
src/User/Store.hs                 メモリ内ストア（IORef + Data.Map.Strict）
src/User/Server.hs                Userハンドラ
app/Main.hs                       エントリポイント
test/unit/                        機能ごとのserver値を直接検証する単体テスト
test/integration/                 機能ごとのAPI型からApplicationを組み立てる結合テスト
docs/iteration-1.md               設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-1.md`

対応する演習用プロジェクトは`../exercise`である。
