# saas-handson-iteration3（演習）

HaskellとServantで作るtoB SaaSハンズオン教材、Iteration 3の演習用
プロジェクトである。

## このIterationで作るもの

JWTの`tenant_id`クレームに基づいて、ユーザーデータをテナントごとに
完全に分離する。

## 進め方

1. `docs/iteration-3.md`を読み、演習3-1から順に取り組む。
2. `cabal test saas-handson-iteration3:test:unit saas-handson-iteration3:test:integration`
   でテストの状態を確認しながら進める。
3. 最後にあるテストがGREENになることを確認する。
4. 行き詰まった場合は`../solution/`の同名ファイル・
   `../solution/docs/iteration-3.md`を参照する。

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
# 単体テスト（実DB・外部サービスに一切依存しない）
cabal test saas-handson-iteration3:test:unit

# 結合テスト（テスト専用の鍵ペアでJWTを検証する。mock-authサービスには
# 依存しない）
cabal test saas-handson-iteration3:test:integration

# サーバーを起動する（devcontainerのmock-authサービスに接続する）
cabal run saas-handson-iteration3
```

## ディレクトリ構成

```
src/Auth/Types.hs, Server.hs   TenantIdの追加・tenant_idクレームの抽出が演習
src/Health/                    ヘルスチェック機能（変更不要）
src/User/Api.hs                変更不要（AuthProtect "jwt"はIteration 2で追加済み）
src/User/Server.hs             authTenantIdをUser.Storeに渡すのが演習
src/User/Store.hs              テナントでスコープするのが演習
test/                          既存のテストの認証対応・テナント分離のテスト追加が演習
docs/iteration-3.md            演習手順
```

## 資料

- 演習手順：`docs/iteration-3.md`
- 行き詰まった場合の解答例：`../solution/`
