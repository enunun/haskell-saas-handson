# saas-handson-solution-iteration6（解答例）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 6の解答例
プロジェクトである。全Iteration（0〜6）の中で最後のIterationであり、
このプロジェクトの完成形が教材全体のゴールにあたる。

## 現在の状態

構造化ログ（リクエスト単位のログ、認証済みユーザー・テナントIDの
付与、ログレベルの使い分け）が導入されている。`wai-extra`による
HTTPアクセスログも出力される。単体テスト・結合テストともにGREENで
ある。

## 実行方法

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
cabal test saas-handson-solution-iteration6:test:unit
cabal test saas-handson-solution-iteration6:test:integration
cabal run saas-handson-solution-iteration6
```

## 疎通確認

```sh
cabal run saas-handson-solution-iteration6

# 別ターミナルから
curl http://localhost:8080/health

TOKEN=$(curl -s -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials -d client_id=alice -d client_secret=dummy \
  -d 'claims={"tenant_id":"acme","role":"admin"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl -X POST http://localhost:8080/users -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"name":"Alice","email":"alice@example.com"}'
curl http://localhost:8080/users -H "Authorization: Bearer $TOKEN"
```

サーバーの標準出力に、`wai-extra`によるHTTPアクセスログと、
`Logging.Stdout`による構造化ドメインログ（`user_created`等、1行1JSON）
の両方が出力される。

## ディレクトリ構成

```
src/Logging.hs                Loggerインターフェース（Handleパターン）
src/Logging/Stdout.hs          標準出力へJSON行を出力する実装（本番用）
src/Logging/Capturing.hs       メモリに記録する実装（テスト用）
src/User/Server.hs              Loggerを注入し構造化ログを出力するハンドラ
src/Auth/, src/User/Repository*, src/User/Error.hs, src/User/Types.hs
                                Iteration 5までの実装
app/Main.hs                    エントリポイント（wai-extraのアクセスログを含む）
test/                           機能ごとのテスト（Userはログ出力も検証）
docs/iteration-6.md             設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-6.md`
- 全体のロードマップ：`../../docs/ROADMAP.md`

対応する演習用プロジェクトは`../exercise`である。
