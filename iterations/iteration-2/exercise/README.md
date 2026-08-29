# saas-handson-iteration2（演習）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 2の演習用
プロジェクトである。

## このIterationで作るもの

外部認証サーバーが発行するJWTをServantの`AuthProtect`で検証し、
`POST /users`・`GET /users`・`GET /users/{id}`を認証必須にする。
`GET /health`は引き続き認証不要のままとする。

## 進め方

1. `docs/iteration-2.md`を読み、演習2-1から順に取り組む。
2. `cabal test saas-handson-iteration2:test:unit saas-handson-iteration2:test:integration`
   でテストの状態を確認しながら進める。
3. 最後にあるテストがGREENになることを確認する。
4. 行き詰まった場合は`../solution/`の同名ファイル・
   `../solution/docs/iteration-2.md`を参照する。

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト（実DB・外部サービスに一切依存しない）
cabal test saas-handson-iteration2:test:unit

# 結合テスト（テスト専用の鍵ペアでJWTを検証する。mock-authサービスには
# 依存しない）
cabal test saas-handson-iteration2:test:integration

# サーバーを起動する（devcontainerのmock-authサービスに接続する）
cabal run saas-handson-iteration2
```

## ディレクトリ構成

```
src/Auth/Types.hs, Server.hs   JWT検証（完成済み。読んで理解する）
src/Health/                    ヘルスチェック機能（変更不要）
src/User/Api.hs                UserのAPI型（AuthProtect "jwt"を追加するのが演習）
src/User/Server.hs             Userハンドラ（AuthenticatedUser引数を追加するのが演習）
src/User/Store.hs, Types.hs    変更不要
src/Server.hs                  serveWithContextへの切り替えが演習
app/Main.hs                    JWKStoreの生成・配線が演習
test/                          既存のUserテストを認証対応に書き換えるのが演習
docs/iteration-2.md            演習手順
```

## 資料

- 演習手順：`docs/iteration-2.md`
- 行き詰まった場合の解答例：`../solution/`
