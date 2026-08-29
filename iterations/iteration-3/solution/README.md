# saas-handson-solution-iteration3（解答例）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 3の解答例
プロジェクトである。

## 現在の状態

JWTの`tenant_id`クレームに基づいて、ユーザーデータがテナントごとに
完全に分離されている。単体テスト・結合テストともにGREENである。

## 実行方法

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト（実DB・外部サービスに一切依存しない）
cabal test saas-handson-solution-iteration3:test:unit

# 結合テスト（テスト専用の鍵ペアでJWTを検証する。mock-authサービスには
# 依存しない）
cabal test saas-handson-solution-iteration3:test:integration

# サーバーを起動する（devcontainerのmock-authサービスに接続する）
cabal run saas-handson-solution-iteration3
```

## 疎通確認

```sh
cabal run saas-handson-solution-iteration3

# 別ターミナルから
TOKEN_ACME=$(curl -s -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials -d client_id=alice -d client_secret=dummy \
  -d 'claims={"tenant_id":"acme"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl -X POST http://localhost:8080/users -H "Authorization: Bearer $TOKEN_ACME" \
  -H 'Content-Type: application/json' -d '{"name":"Alice","email":"alice@example.com"}'
curl http://localhost:8080/users -H "Authorization: Bearer $TOKEN_ACME"
```

## ディレクトリ構成

```
src/Auth/Types.hs                 AuthenticatedUser（TenantId追加）
src/Auth/Server.hs                 JWT検証（tenant_idクレームの抽出込み）
src/Health/                        ヘルスチェック機能（認証不要）
src/User/Api.hs                    UserのAPI型（Iteration 2から変更なし）
src/User/Server.hs                 authTenantIdでStoreをスコープする
src/User/Store.hs                  テナントごとに分離したメモリ内ストア
src/User/Types.hs                  Iteration 1から変更なし
src/Api.hs, Server.hs              機能ごとのAPI型・server値を合成するcombinator
app/Main.hs                        エントリポイント
test/                              機能ごとのテスト（Userはテナント分離込みで検証）
docs/iteration-3.md                設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-3.md`

対応する演習用プロジェクトは`../exercise`である。
