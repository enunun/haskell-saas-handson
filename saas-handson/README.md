# saas-handson

HaskellとServantで作るtoB SaaSハンズオン教材の演習用プロジェクトである。

## 現在の状態

Iteration 0：`test/HealthSpec.hs`は用意済みだが、`src/Server.hs`の実装が
TODOのままであり、テストはREDである。

## 進め方

コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

```sh
cabal test saas-handson
```

まず上記を実行し、単体テスト（`test/unit`）・結合テスト（`test/integration`）
の両方が失敗（RED）することを確認する。次に`src/Server.hs`内の
`healthHandler`を実装し、再度`cabal test saas-handson`を実行して両方
GREENにする。実装後は`docs/iteration-0.md`を読み、書いたコードがどの
設計パターンに対応するか、また単体テストと結合テストの役割の違いを
確認するとよい。

GREENになったら以下でサーバーを起動し、実際に疎通確認する。

```sh
cabal run saas-handson
curl http://localhost:8080/health
```

## ディレクトリ構成

```
src/Api.hs      API型定義（変更不要）
src/Types.hs    リクエスト・レスポンス型（変更不要）
src/Server.hs   ハンドラ実装（ここを実装する）
app/Main.hs     エントリポイント
test/unit/          ハンドラを直接検証する単体テスト（既に用意済み）
test/integration/   WAI Application相手に検証する結合テスト（既に用意済み）
docs/           各イテレーションの設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-0.md`
- 全体のロードマップ：`docs/ROADMAP.md`

行き詰まった場合は`saas-handson-solution`の同名ファイルを参照する。
