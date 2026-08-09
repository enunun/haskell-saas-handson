# saas-handson-solution

HaskellとServantで作るtoB SaaSハンズオン教材の解答例プロジェクトである。

## 現在の状態

Iteration 0〜6（ヘルスチェック、ユーザー登録・一覧、JWT認証、
マルチテナント対応、永続化層〈PostgreSQL〉、権限管理・エラー設計、
ロギング）すべて完了。単体テスト（実DB非依存）・結合テスト（実DB
`db`サービスに依存）ともに全件GREENである。

## 実行方法

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト（実DB・外部サービスに一切依存しない）
cabal test saas-handson-solution:test:unit

# 結合テスト（devcontainerのdbサービスに依存する）
cabal test saas-handson-solution:test:integration

# 両方まとめて
cabal test saas-handson-solution

cabal run saas-handson-solution
```

結合テストを初めて実行する前に、PostgreSQLのスキーマを`psqldef`で適用
しておく必要がある（`docs/iteration-4.md`の「事前準備」を参照）。

```sh
PGPASSWORD=postgres psqldef -U postgres -h db saas_handson --apply -f db/schema.sql
```

## 疎通確認

`/health`以外のエンドポイントはJWTによる認証が必要（Iteration 2）で、
`POST /users`はさらに`role=admin`のトークンが必要（Iteration 5）。

```sh
cabal run saas-handson-solution

# 別ターミナルから
curl http://localhost:8080/health

TOKEN=$(curl -s -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials -d client_id=alice -d client_secret=dummy \
  -d 'claims={"tenant_id":"acme","role":"admin"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl -X POST http://localhost:8080/users \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com"}'

curl http://localhost:8080/users -H "Authorization: Bearer $TOKEN"
```

サーバーの標準出力に、`wai-extra`によるHTTPアクセスログと、
`Logging.Stdout`による構造化ドメインログ（`user_created`等、1行1JSON）
の両方が出力される（Iteration 6）。

## ディレクトリ構成

機能（Health, User, ...）ごとにAPI型・ハンドラ・データ型をまとめる
Vertical Slice構成に、横断的関心事（認証・永続化・ロギング）を
Handleパターン（レコード・オブ・関数）で注入する設計を組み合わせて
いる。詳細は各`docs/iteration-N.md`を参照。

```
src/Api.hs                        機能ごとのAPI型を:<|>で合成するcombinator
src/Server.hs                      機能ごとのserverを:<|>で合成し、Auth/Logger/Repositoryを配線するcombinator
src/Health/                        ヘルスチェック機能（Api.hs, Server.hs, Types.hs。認証不要）
src/User/Api.hs                    UserのAPI型（AuthProtect "jwt"を付与）
src/User/Types.hs                  User, CreateUserRequest
src/User/Server.hs                 Userハンドラ（認可・バリデーション・ロギングを含む）
src/User/Error.hs                  ドメインエラー型UserErrorとHTTPへのマッピング
src/User/Repository.hs             UserRepositoryインターフェース（Handleパターン）
src/User/Repository/InMemory.hs    in-memory実装（単体テスト用）
src/User/Repository/Postgres.hs    PostgreSQL実装（本番・結合テスト用）
src/Auth/Types.hs                  AuthenticatedUser, TenantId, Role
src/Auth/Server.hs                 JWT検証（JWKS取得・署名検証・クレーム抽出）
src/Logging.hs                     Loggerインターフェース（Handleパターン）
src/Logging/Stdout.hs              標準出力へJSON行を出力する実装（本番用）
src/Logging/Capturing.hs           メモリに記録する実装（テスト用）
app/Main.hs                        エントリポイント（各Handleの実装を組み立てる）
test/unit/                         ハンドラを直接検証する単体テスト（in-memory実装・Capturing実装のみ使用）
test/integration/                  WAI Application相手に検証する結合テスト（PostgreSQL実装を使用）
db/schema.sql                      PostgreSQLスキーマ定義（psqldefで適用、リポジトリルート）
docs/                              各Iterationの設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-0.md`〜`docs/iteration-6.md`
- 全体のロードマップ：`docs/ROADMAP.md`

対応する演習用プロジェクトは`saas-handson`である。各Iterationの
`docs/iteration-N.md`が演習問題（`saas-handson`側）と解答解説
（このプロジェクト側）に1対1で対応している。
