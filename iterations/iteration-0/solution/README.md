# saas-handson-solution-iteration0（解答例）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 0の解答例
プロジェクトである。

## 現在の状態

`GET /health`エンドポイント（ヘルスチェックAPI）が完成している。単体
テスト・結合テストともにGREENである。

## 実行方法

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト
cabal test saas-handson-solution-iteration0:test:unit

# 結合テスト
cabal test saas-handson-solution-iteration0:test:integration

# 両方まとめて
cabal test saas-handson-solution-iteration0

# サーバーを起動する
cabal run saas-handson-solution-iteration0
# 別ターミナルから
curl http://localhost:8080/health
```

## ディレクトリ構成

```
src/Api.hs        HealthのAPI型
src/Server.hs     Healthハンドラ実装
src/Types.hs      HealthResponse
app/Main.hs       エントリポイント
test/unit/        ハンドラを直接検証する単体テスト
test/integration/ WAI Application相手に検証する結合テスト
docs/iteration-0.md  設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-0.md`

対応する演習用プロジェクトは`../exercise`である。
