# saas-handson-solution

HaskellとServantで作るtoB SaaSハンズオン教材の解答例プロジェクトである。

## 現在の状態

Iteration 0（`GET /health`のTDD実装）完了。全テストがGREENである。

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
```

## ディレクトリ構成

```
src/Api.hs      API型定義
src/Types.hs    リクエスト・レスポンス型
src/Server.hs   ハンドラ実装
app/Main.hs     エントリポイント
test/unit/          ハンドラを直接検証する単体テスト
test/integration/   WAI Application相手に検証する結合テスト
docs/           各イテレーションの設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-0.md`
- 全体のロードマップ：`docs/ROADMAP.md`

対応する演習用プロジェクトは`saas-handson`である。同じテストを先に読み、
`src/Server.hs`のハンドラをTODOから実装することでTDDサイクルを体験できる。
