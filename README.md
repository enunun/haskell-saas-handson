# saas-handson-suite

HaskellとServantでtoB SaaSを構築するTDD/アジャイル形式のハンズオン教材。
演習用プロジェクトと解答例プロジェクトを1つのcabalマルチパッケージ構成に
まとめたリポジトリである。

## このハンズオンで作るもの

全Iteration（`docs/ROADMAP.md`参照）を終えると、以下の機能・構造を持つ
最小限のtoB SaaSバックエンドAPIが完成する（完成形は`saas-handson-solution`、
これから同じ形を目指して実装するのが`saas-handson`）。

### 機能

| エンドポイント | 認証・認可 | 内容 |
|---|---|---|
| `GET /health` | 不要 | ロードバランサ等からの死活監視用 |
| `POST /users` | JWT必須・`role=admin`のみ | 自分のテナント内にユーザーを登録する |
| `GET /users` | JWT必須 | 自分のテナント内のユーザー一覧を返す |

- **認証**：外部の認証サーバー（本教材ではローカル開発用に
  mock-oauth2-serverを使用。実運用ならKeycloak等のOIDCプロバイダに
  相当）が発行するJWTを検証する。パスワード管理・ログイン画面は
  自前で実装しない。
- **マルチテナント**：JWTの`tenant_id`クレームに基づき、契約企業
  （テナント）ごとにユーザーデータを完全に分離する。あるテナントの
  ユーザーが他テナントのデータへ到達する経路は存在しない。
- **権限管理**：JWTの`role`クレーム（`admin`／`member`）に基づき、
  ユーザー登録は`admin`のみに制限する。
- **エラー設計**：権限不足・不正な入力といった失敗は、HTTPの都合から
  独立したドメインエラー型として表現し、それを1箇所でHTTPステータス
  コード・JSON形式のエラーボディへ変換する。
- **永続化**：PostgreSQLにユーザーデータを保存する。ID採番はDB側の
  `SERIAL`に委ね、アプリケーション側は採番ロジックを持たない。
- **可観測性**：HTTPアクセスログ（リクエスト単位）と、
  構造化されたドメインログ（「誰が・どのテナントとして・何をしたか」を
  JSON行として記録）の両方を出力する。

### アーキテクチャ

- **Vertical Slice構成**：技術層（Controller／Service／Repository…）
  ではなく機能（`Health/`・`User/`）ごとにAPI型・ハンドラ・データ型を
  まとめる。
- **Handleパターンによる依存性注入（DI）**：認証（`JWKStore`）・
  永続化（`UserRepository`）・ロギング（`Logger`）といった横断的関心事
  はいずれも「レコード・オブ・関数」というHaskellでのDIの実現方法で
  抽象化し、本番用の実装とテスト用の実装（in-memory／JWKSetを直接
  注入／メモリに記録するだけのLogger）を差し替えられるようにしている。
  OOPで言うインターフェース＋DIコンテナに相当することを、
  関数の引数として値を渡すだけで実現している。
- **テストピラミッド**：単体テストは外部サービス（実DB・実認証サーバー）
  に一切依存しない（in-memory実装・Capturing実装のみを使用）。実際の
  PostgreSQLに依存する検証は結合テストに閉じ込める。
- **型でドメインを表現する**：「誰が・どのテナントの・どういう役割で
  アクセスしているか」（`AuthenticatedUser`）、「何が失敗したか」
  （`UserError`）を、いずれもHaskellの型として明示的に表現し、
  Servantのルーティング・ハンドラ・ロギングの各所でそのまま再利用する。

Servant（型レベルAPI定義）・`jose`（JWT検証）・`postgresql-simple`＋
`resource-pool`（永続化）・`fast-logger`＋`wai-extra`（ロギング）・
`psqldef`（宣言的DBマイグレーション）といったライブラリ・ツールを使う。
各要素の設計判断の背景は、対応する`docs/iteration-N.md`
（`saas-handson-solution`側）で詳しく解説している。

## リポジトリ構成

```
cabal.project              全パッケージを列挙するルート定義（LSPが参照する）
.devcontainer/              VSCode + Docker Composeによる開発環境定義
db/schema.sql                PostgreSQLスキーマ定義（psqldefで適用。両パッケージ共有）
saas-handson/                演習用プロジェクト
saas-handson-solution/       解答例プロジェクト
```

`saas-handson`と`saas-handson-solution`は同じAPI仕様・同じテストを持つ
独立したcabalパッケージである。両者は個別のcabal.projectを持たず、
ルートの`cabal.project`が両方を束ねる。

```yaml
# cabal.project
packages:
  saas-handson
  saas-handson-solution
```

haskell-language-serverはこのファイルを起点にプロジェクト構成を解決する
ため、パッケージを追加した際は必ずこのファイルにも追記する。ルートに
列挙されていないパッケージは、たとえディレクトリが存在してもLSPの補完・
型検査・診断の対象外となる。

## 開発環境（VSCode + Dev Container）

このリポジトリは[Dev Containers](https://containers.dev/)に対応している。

1. VSCodeに拡張機能「Dev Containers」（`ms-vscode-remote.remote-containers`）
   をインストールする
2. Dockerを起動した状態でこのリポジトリをVSCodeで開く
3. 右下の通知、またはコマンドパレットから
   「Dev Containers: Reopen in Container」を実行する

devcontainerはdocker compose（`.devcontainer/docker-compose.yml`）で
構成されており、以下の3つのコンテナが一緒に起動する。

- `app`：開発用コンテナ本体。GHC・cabal（`haskell:9.14.1`イメージ由来）・
  haskell-language-server（HLS）・`rtk`・`psqldef`を含む
- `mock-auth`：JWTを発行するモック認証サーバー（Iteration 2以降で使用、
  `mock-oauth2-server`）。`app`からは`http://mock-auth:8080`でアクセス
  できる
- `db`：PostgreSQL（Iteration 4以降で使用）。`app`からは
  `host=db port=5432`でアクセスできる

VSCode拡張機能：

- `haskell.haskell`（公式Haskell拡張、HLS連携）
- `justusadam.language-haskell`（シンタックスハイライト）
- `EditorConfig.EditorConfig`

コンテナ起動時に`cabal update`が自動実行される。

## コマンド

コマンドはすべてリポジトリルートから実行する。

```sh
# 演習用プロジェクトのテスト（単体・結合の両方）
cabal test saas-handson

# 解答例プロジェクトのテスト（単体・結合の両方）
cabal test saas-handson-solution

# 単体テスト／結合テストを個別に実行する場合
cabal test saas-handson-solution:test:unit
cabal test saas-handson-solution:test:integration

# 全パッケージをまとめてビルド
cabal build all
```

**単体テストはPostgreSQL等の外部サービスに一切依存しないが、結合
テスト（Iteration 4以降のもの）は`db`サービスに依存する。** 初回は
結合テストの実行前に`db/schema.sql`を`psqldef`で適用しておく必要が
ある（`saas-handson-solution/docs/iteration-4.md`の「事前準備」を参照）。

```sh
PGPASSWORD=postgres psqldef -U postgres -h db saas_handson --apply -f db/schema.sql
```

## 進め方・資料

- 演習の進め方：`saas-handson/README.md`
- 解答例：`saas-handson-solution/README.md`
- 設計パターン・ライブラリの解説：各プロジェクトの
  `docs/iteration-0.md`〜`docs/iteration-6.md`
- 全体ロードマップ（各Iterationの目的・実装内容・状態）：
  各プロジェクトの`docs/ROADMAP.md`
- 作業ログ・進捗の詳細：`PROGRESS.md`
