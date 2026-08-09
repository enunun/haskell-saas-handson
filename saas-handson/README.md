# saas-handson

HaskellとServantで作るtoB SaaSハンズオン教材の演習用プロジェクトである。

## 現在の状態

| Iteration | 内容 | 状態 |
|---|---|---|
| 0 | ヘルスチェックAPI（`GET /health`） | 着手中（テストRED） |
| 1 | ユーザー登録・一覧、Vertical Sliceへのリファクタリング | 着手中（テストRED） |
| 2 | JWT認証（`AuthProtect`） | 着手中（テストRED） |
| 3 | マルチテナント対応（`tenant_id`クレーム） | 着手中（テストRED） |
| 4 | 永続化層（PostgreSQL、Repository抽象化） | 着手中（テストRED） |
| 5 | 権限管理・エラー設計（`role`クレーム、`UserError`） | 着手中（テストRED） |
| 6 | ロギング・可観測性（構造化ログ） | 着手中（テストRED） |

各Iterationの演習手順は`docs/iteration-0.md`〜`docs/iteration-6.md`に
ある。**この順番で読み進めること**（後のIterationは、前のIterationで
導入した型・設計をそのまま前提として使う。例：Iteration 3の
テナント分離はIteration 2の`AuthenticatedUser`を、Iteration 6のログは
Iteration 3・5の型をそれぞれ利用する）。全体のロードマップ・各
Iterationの目的は`docs/ROADMAP.md`を参照。

## 進め方

1. `docs/iteration-0.md`を読み、演習0-1から順に取り組む。
2. `cabal test saas-handson`で単体・結合テストの状態を確認しながら
   進める。
3. 各Iterationの最後にあるテストがGREENになることを確認してから次の
   Iterationへ進む。
4. 行き詰まった場合は`saas-handson-solution`の同名ファイル・
   `saas-handson-solution/docs/iteration-N.md`を参照する。

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト（実DB・外部サービスに一切依存しない）
cabal test saas-handson:test:unit

# 結合テスト（devcontainerのdbサービスに依存する。Iteration 4以降で必要）
cabal test saas-handson:test:integration

# 両方まとめて
cabal test saas-handson
```

## 外部サービスへの依存（Iteration 2以降）

Iteration 2（認証）以降は、devcontainerを開いた時点で一緒に起動する
以下のサービス（`.devcontainer/docker-compose.yml`）に依存する。

- `mock-auth`：JWTを発行するモック認証サーバー
  （コンテナ内から`http://mock-auth:8080`）
- `db`：PostgreSQL（コンテナ内から`host=db port=5432`）。Iteration 4
  以降で使用する。結合テストを実行する前に、`db/schema.sql`を
  `psqldef`で適用しておく必要がある（手順は`docs/iteration-4.md`の
  「事前準備」を参照）。

**単体テスト（`cabal test saas-handson:test:unit`）はこれらのサービスに
一切依存しない。** dbサービスが落ちていても、devcontainerの外でも常に
実行できる。

## 疎通確認

Iteration 2以降、`/health`以外のエンドポイントはJWTによる認証が必要に
なる。

```sh
cabal run saas-handson

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

## ディレクトリ構成

現時点（Iteration 1のリファクタリング着手前）の構成。TODOの実装が
進むにつれ、`saas-handson-solution`と同じ形に近づいていく。

```
src/Api.hs                        Health＋UserのAPI型（今はHealthをinlineで含む暫定形）
src/Server.hs                      Healthハンドラ実装（TODO）＋User・Auth・Loggerの配線
src/Types.hs                       HealthResponse（変更不要）
src/Auth/Types.hs                  AuthenticatedUser, TenantId, Role（変更不要）
src/Auth/Server.hs                 JWT検証（verifyがTODO）
src/User/Api.hs                    UserのAPI型（変更不要）
src/User/Types.hs                  User, CreateUserRequest（変更不要）
src/User/Server.hs                 Userハンドラ実装（createUserHandlerがTODO）
src/User/Error.hs                  ドメインエラー型（toServerErrorがTODO）
src/User/Repository.hs             UserRepositoryインターフェース（変更不要）
src/User/Repository/InMemory.hs    in-memory実装（TODO）
src/User/Repository/Postgres.hs    PostgreSQL実装（TODO）
src/Logging.hs                     Loggerインターフェース（変更不要）
src/Logging/Stdout.hs              標準出力実装（writeEntryがTODO）
src/Logging/Capturing.hs           テスト用実装（変更不要）
app/Main.hs                        エントリポイント
test/unit/                         ハンドラを直接検証する単体テスト（実DB非依存）
test/integration/                  WAI Application相手に検証する結合テスト（一部実DB依存）
db/schema.sql                      PostgreSQLスキーマ定義（psqldefで適用、リポジトリルート）
docs/                              各Iterationの演習・設計解説
```

## 資料

- 演習手順：`docs/iteration-0.md`〜`docs/iteration-6.md`
- 全体のロードマップ：`docs/ROADMAP.md`

行き詰まった場合は`saas-handson-solution`の同名ファイル・
`saas-handson-solution/docs/iteration-N.md`を参照する。
