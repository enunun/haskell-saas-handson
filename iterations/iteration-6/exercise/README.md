# saas-handson-iteration6（演習）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 6の演習用
プロジェクトである。

## このIterationで作るもの

構造化ログ（リクエスト単位のログ、認証済みユーザー・テナントIDの
付与）を導入する。`Logger`を`UserRepository`・`JWKStore`と同じHandle
パターンで注入し、本番用（標準出力へJSON行）・テスト用（メモリに記録）
の2実装を用意する。

## 進め方

1. `docs/iteration-6.md`を読み、演習6-1から順に取り組む。
2. `cabal test saas-handson-iteration6:test:unit`（実DB不要）・
   `cabal test saas-handson-iteration6:test:integration`（`db`サービス
   が必要）でテストの状態を確認しながら進める。
3. 最後にあるテストがGREENになることを確認する。
4. 行き詰まった場合は`../solution/`の同名ファイル・
   `../solution/docs/iteration-6.md`を参照する。

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
cabal test saas-handson-iteration6:test:unit
cabal test saas-handson-iteration6:test:integration
cabal run saas-handson-iteration6
```

## ディレクトリ構成

```
src/Logging.hs                Loggerインターフェース（完成済み）
src/Logging/Stdout.hs         標準出力へ出力する本番実装（完成済み。読んで理解する）
src/Logging/Capturing.hs      テスト用実装（TODO）
src/User/Server.hs            Loggerの注入・ログ出力の追加が演習
src/Server.hs, app/Main.hs    Loggerの組み立て・配線、wai-extraの導入が演習
test/                         Logger経由へのテスト書き換え・ログ検証テストの追加が演習
docs/iteration-6.md           演習手順
```

## 資料

- 演習手順：`docs/iteration-6.md`
- 行き詰まった場合の解答例：`../solution/`
