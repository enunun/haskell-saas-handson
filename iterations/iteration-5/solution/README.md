# saas-handson-solution-iteration5（解答例）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 5の解答例
プロジェクトである。

## 現在の状態

JWTの`role`クレームに基づき、`POST /users`が`admin`だけに許可されて
いる。HTTPの都合から独立したドメインエラー型`UserError`
（`Forbidden`・`InvalidEmail`）を導入し、`throwUserError`で
ステータスコード・JSONボディへ変換している。単体テスト・結合テスト
ともにGREENである。

## 実行方法

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
cabal test saas-handson-solution-iteration5:test:unit
cabal test saas-handson-solution-iteration5:test:integration
cabal run saas-handson-solution-iteration5
```

## ディレクトリ構成

```
src/Auth/Types.hs               AuthenticatedUser（Role追加）
src/Auth/Server.hs               JWT検証（roleクレームの抽出込み）
src/User/Error.hs                ドメインエラー型UserErrorとHTTPへのマッピング
src/User/Server.hs               権限チェック・メールアドレス検証を含むハンドラ
src/User/Repository*, Types.hs   Iteration 4から変更なし
test/                            権限・入力検証を含めて検証するテスト
docs/iteration-5.md              設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-5.md`

対応する演習用プロジェクトは`../exercise`である。
