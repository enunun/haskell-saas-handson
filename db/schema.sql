-- saas_handsonデータベースのスキーマ定義書（宣言的マイグレーション）。
--
-- psqldef（https://github.com/sqldef/sqldef）でこのファイルを適用する。
-- psqldefは「変更したい手順」ではなく「あるべき最終形」を宣言的に記述
-- するツールで、実行中のDBの現在の状態とこのファイルを比較し、差分
-- （CREATE TABLE・ALTER TABLE等）を自動的に計算して適用する。そのため
-- このファイルは「マイグレーション手順書」ではなく、そのまま
-- 「テーブル定義書」として読める（常に最新のスキーマそのものである）。
--
-- 適用方法はsaas-handson・saas-handson-solution双方の
-- docs/iteration-4.mdを参照。

-- users: Iteration 1で導入したユーザーリソース。Iteration 3のマルチ
-- テナント対応でtenant_id列を追加した。idの採番はIteration 4で
-- アプリケーション側からDB側（SERIAL）に委ねている。
CREATE TABLE users (
  id        SERIAL PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  name      TEXT NOT NULL,
  email     TEXT NOT NULL
);
