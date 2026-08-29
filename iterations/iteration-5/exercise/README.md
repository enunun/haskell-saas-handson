# saas-handson-iteration5（演習）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 5の演習用
プロジェクトである。

## このIterationで作るもの

JWTの`role`クレームに基づいて`POST /users`を`admin`だけに許可する。
HTTPの都合から独立したドメインエラー型`UserError`を導入し、
権限不足（403）・不正なメールアドレス（400）をこの型経由で表現する。

## 進め方

1. `docs/iteration-5.md`を読み、演習5-1から順に取り組む。
2. `cabal test saas-handson-iteration5:test:unit`（実DB不要）・
   `cabal test saas-handson-iteration5:test:integration`（`db`サービス
   が必要）でテストの状態を確認しながら進める。
3. 最後にあるテストがGREENになることを確認する。
4. 行き詰まった場合は`../solution/`の同名ファイル・
   `../solution/docs/iteration-5.md`を参照する。

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
cabal test saas-handson-iteration5:test:unit
cabal test saas-handson-iteration5:test:integration
cabal run saas-handson-iteration5
```

## ディレクトリ構成

```
src/Auth/Types.hs, Server.hs   Roleの追加・roleクレームの抽出が演習
src/User/Error.hs               UserError型は定義済み、throwUserErrorがTODO
src/User/Server.hs              権限チェック・メールアドレス検証の追加が演習
test/                           既存テストの認証対応・権限/検証のテスト追加が演習
docs/iteration-5.md             演習手順
```

## 資料

- 演習手順：`docs/iteration-5.md`
- 行き詰まった場合の解答例：`../solution/`
