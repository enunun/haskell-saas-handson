# saas-handson-iteration0（演習）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 0の演習用
プロジェクトである。

## このIterationで作るもの

`GET /health`エンドポイント（ヘルスチェックAPI）。サーバーが正常に
起動しリクエストを処理できる状態にあるかを外部から確認するための、
最小のエンドポイントを、Servantプロジェクトの雛形（型レベルAPI・
ハンドラ・テスト環境）とともに構築する。

## 進め方

1. `docs/iteration-0.md`を読み、演習0-1から順に取り組む。
2. `cabal test saas-handson-iteration0`で単体・結合テストの状態を
   確認しながら進める（演習0-2でテスト自体を自分で書くところから
   始まる）。
3. 最後にあるテストがGREENになることを確認する。
4. 行き詰まった場合は`../solution/`の同名ファイル・
   `../solution/docs/iteration-0.md`を参照する。

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト
cabal test saas-handson-iteration0:test:unit

# 結合テスト
cabal test saas-handson-iteration0:test:integration

# 両方まとめて
cabal test saas-handson-iteration0

# サーバーを起動する
cabal run saas-handson-iteration0
# 別ターミナルから
curl http://localhost:8080/health
```

## ディレクトリ構成

```
src/Api.hs        HealthのAPI型（変更不要）
src/Server.hs     Healthハンドラ実装（healthHandlerがTODO）
src/Types.hs      HealthResponse（変更不要）
app/Main.hs       エントリポイント
test/unit/        ハンドラを直接検証する単体テスト（演習0-2で自作する）
test/integration/ WAI Application相手に検証する結合テスト（演習0-2で自作する）
docs/iteration-0.md  演習手順
```

## 資料

- 演習手順：`docs/iteration-0.md`
- 行き詰まった場合の解答例：`../solution/`
