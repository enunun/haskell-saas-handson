# ロードマップ

本教材は、汎用的なtoB SaaSのバックエンドをHaskellとServantでTDD駆動かつ
インクリメンタルに構築するハンズオンである。各イテレーションはRed-Green-
Refactorのサイクルを1回以上含み、完了時点で常に完全に動作する状態を保つ。

## Iteration 0：プロジェクト雛形

- **実装する機能**：ヘルスチェックAPI（`GET /health`）
- **目的**：ロードバランサやオーケストレータによる死活監視に応答する
  エンドポイントを、ビルド・テスト環境の雛形として構築する
- **状態**：着手中（テストREDの状態）

## Iteration 1：ユーザー登録・一覧

- **実装する機能**：`POST /users`（ユーザー登録）、`GET /users`（一覧取得）
  ※データはin-memoryで保持する
- **含むリファクタリング**：機能が2つ（Health, User）になるタイミングで、
  技術層別構成（`src/Api.hs`／`Server.hs`／`Types.hs`）から機能別
  ディレクトリ構成（`src/Health/`, `src/User/`というVertical Slice）へ
  移行する。1機能しか存在しないIteration 0の段階で先回りして機能別に
  分けるのはYAGNIに反するため、境界の引き方が実際に見えるこの
  タイミングで行う（詳細は`docs/iteration-1.md`）
- **目的**：toB SaaSの土台となるユーザーリソースのCRUDを、永続化を伴わない
  最小構成で確立する
- **状態**：着手中（テストREDの状態。Healthのリファクタリング・Userの
  実装ともに未着手）

## Iteration 2：認証

- **実装する機能**：外部認証サーバー（mock-oauth2-server、ローカル開発
  はdocker-compose）が発行するJWTをServantの`AuthProtect`で検証する、
  トークン認証によるAPIアクセス制御。`POST /users`・`GET /users`を保護し、
  `GET /health`は引き続き認証なしとする
- **目的**：未認証のリクエストを拒否し、以降のイテレーションで扱う
  「誰がアクセスしているか」を`AuthenticatedUser`型で表現できるように
  する
- **状態**：着手中（テストRED。JWT検証ロジック（`src/Auth/Server.hs`の
  `verify`）・Iteration 0/1のTODOが未実装）

## Iteration 3：マルチテナント対応

- **実装する機能**：JWTの`tenant_id`クレームに基づくデータ分離。
  `AuthenticatedUser`にテナントIDを追加し、`POST /users`・`GET /users`
  のin-memoryストアをテナントIDでスコープする
- **目的**：toB SaaSに不可欠な「契約企業ごとにデータを隔離する」という
  要件を、Servantのコンテキストや型（`AuthenticatedUser`・
  `Map TenantId (...)`）を使って表現する
- **状態**：着手中（テストRED。JWT検証への`tenant_id`抽出追加
  （`src/Auth/Server.hs`の`verify`）・Iteration 0/1のTODOが未実装）

## Iteration 4：永続化層の導入

- **実装する機能**：in-memoryストアからPostgreSQL（`postgresql-simple`
  ＋`resource-pool`）への置き換え。`UserRepository`（Handleパターンに
  よるレコード・オブ・関数、OOPで言うDIのHaskellでの実現方法）で
  Repository抽象化し、in-memory実装・PostgreSQL実装の両方を用意する。
  自動発番はPostgreSQLの`SERIAL`＋`RETURNING id`に委ね、アプリケーション
  側の採番ロジック・ロック制御を不要にする
- **目的**：ハンドラの実装をデータ格納方式から独立させ、テスト容易性を
  保ったまま永続化を導入する。単体テストはin-memory実装のみを使い実DBに
  一切依存しない、結合テストはPostgreSQL（docker-composeの`db`サービス）
  に依存してよい、という層分けを徹底する
- **状態**：着手中（テストRED。`User.Repository.InMemory`・
  `User.Repository.Postgres`のCRUDロジック・Iteration 0〜3のTODOが
  未実装）

## Iteration 5：権限管理・エラー設計

- **実装する機能**：ドメインエラー型の設計と、Servantでの表現
  （HTTPステータスコードへのマッピングを含む）
- **目的**：ユーザーの権限に応じたアクセス制御と、エラーを型で表現する
  設計を確立する
- **状態**：未着手

各イテレーションの設計パターン・使用ライブラリの解説は`docs/iteration-N.md`
に記載する。
