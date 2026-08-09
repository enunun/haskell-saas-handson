# saas-handson-solution

HaskellとServantで作るtoB SaaSハンズオン教材の解答例プロジェクトである。

## 現在の状態

Iteration 0（`GET /health`）・Iteration 1（`POST /users`, `GET /users`）
ともに完了。全テストがGREENである。

## 実行方法

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テストと結合テストを両方実行
cabal test saas-handson-solution

# 個別に実行する場合
cabal test saas-handson-solution:test:unit
cabal test saas-handson-solution:test:integration

cabal run saas-handson-solution
```

サーバー起動後、以下で疎通確認できる。

```sh
curl http://localhost:8080/health

curl -X POST http://localhost:8080/users \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com"}'

curl http://localhost:8080/users
```

## ディレクトリ構成

機能（Health, User, ...）ごとにAPI型・ハンドラ・データ型をまとめる
Vertical Slice構成を取っている。詳細は`docs/iteration-1.md`を参照。

```
src/Api.hs          機能ごとのAPI型を:<|>で合成するcombinator
src/Server.hs        機能ごとのserverを:<|>で合成するcombinator
src/Health/          ヘルスチェック機能（Api.hs, Server.hs, Types.hs）
src/User/            ユーザー登録・一覧機能（Api.hs, Server.hs, Types.hs）
app/Main.hs          エントリポイント
test/unit/Health/    Healthハンドラを直接検証する単体テスト
test/unit/User/      Userハンドラを直接検証する単体テスト
test/integration/Health/  WAI Application相手に検証する結合テスト
test/integration/User/    同上
docs/                各イテレーションの設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-0.md`, `docs/iteration-1.md`
- 全体のロードマップ：`docs/ROADMAP.md`

対応する演習用プロジェクトは`saas-handson`である。同じテストを先に読み、
`src/Server.hs`・`src/User/Server.hs`のハンドラをTODOから実装し、Iteration 1
ではさらにHealthのリファクタリングも行うことでTDD/Refactorサイクルを体験
できる。
