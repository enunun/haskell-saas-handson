# saas-handson-solution-iteration2（解答例）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 2の解答例
プロジェクトである。

## 現在の状態

外部認証サーバーが発行するJWTを検証し、`POST /users`・`GET /users`・
`GET /users/{id}`が認証必須になっている。`GET /health`は引き続き
認証不要である。単体テスト・結合テストともにGREENである。

## 実行方法

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト（実DB・外部サービスに一切依存しない）
cabal test saas-handson-solution-iteration2:test:unit

# 結合テスト（テスト専用の鍵ペアでJWTを検証する。mock-authサービスには
# 依存しない）
cabal test saas-handson-solution-iteration2:test:integration

# サーバーを起動する（devcontainerのmock-authサービスに接続する）
cabal run saas-handson-solution-iteration2
```

## 疎通確認

```sh
cabal run saas-handson-solution-iteration2

# 別ターミナルから
curl http://localhost:8080/health

TOKEN=$(curl -s -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials -d client_id=alice -d client_secret=dummy \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl -X POST http://localhost:8080/users \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com"}'

curl http://localhost:8080/users -H "Authorization: Bearer $TOKEN"
curl http://localhost:8080/users
```

## ディレクトリ構成

```
src/Auth/Types.hs               AuthenticatedUser, AuthServerData型族インスタンス
src/Auth/Server.hs               JWKStore, JWT検証, AuthHandler
src/Health/                       ヘルスチェック機能（認証不要）
src/User/Api.hs                   UserのAPI型（AuthProtect "jwt"付き）
src/User/Server.hs                Userハンドラ（AuthenticatedUserを受け取る）
src/User/Store.hs, Types.hs       Iteration 1から変更なし
src/Api.hs, Server.hs             機能ごとのAPI型・server値を合成するcombinator
app/Main.hs                       エントリポイント（JWKStoreの生成を含む）
test/                             機能ごとのテスト（Userは認証込みで検証）
docs/iteration-2.md               設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-2.md`

対応する演習用プロジェクトは`../exercise`である。
