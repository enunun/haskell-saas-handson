# saas-handson

HaskellとServantで作るtoB SaaSハンズオン教材の演習用プロジェクトである。

## 現在の状態

Iteration 0：`src/Server.hs`の`healthHandler`実装がTODOのままであり、
テストはREDである。

Iteration 1：`POST /users`・`GET /users`用のテスト（`test/unit/User/`,
`test/integration/User/`）と雛形（`src/User/Api.hs`, `src/User/Types.hs`は
完成済み、`src/User/Server.hs`はTODO）を用意済み。Healthの機能別
ディレクトリへのリファクタリングも含めて、まだ未着手（テストREDの状態）。

## 進め方（Iteration 0）

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

## 進め方（Iteration 1）

`docs/iteration-1.md`を先に読み、Vertical Sliceへのリファクタリングの
動機と、`:<|>`・`ReqBody`・`PostCreated`・`IORef`といった新しい設計要素を
把握してから着手する。

1. `cabal test saas-handson`を実行し、Health（Iteration 0分）・User
   （今回追加分）の現在の状態を確認する。まだIteration 0が未実装の場合は
   `healthHandler`を実装しGREENにする。
2. **リファクタリング**：`src/Api.hs`・`src/Server.hs`・`src/Types.hs`を
   `src/Health/Api.hs`・`src/Health/Server.hs`・`src/Health/Types.hs`へ
   移動し、モジュール名を`Health.Api`・`Health.Server`・`Health.Types`に
   変更する。`test/unit/HealthSpec.hs`・`test/integration/HealthSpec.hs`
   も同様に`test/unit/Health/HealthSpec.hs`・
   `test/integration/Health/HealthSpec.hs`へ移動し、モジュール名を
   `Health.HealthSpec`に変更する。ルートの`src/Api.hs`・`src/Server.hs`を
   `Health.Api`・`Health.Server`をqualified importして`:<|>`で合成する
   combinator形に書き換え（`saas-handson-solution`の同名ファイルが参考に
   なる）、`saas-handson.cabal`の`exposed-modules`・`other-modules`を
   更新する。**この移動の前後でHealthのテスト結果が変わらないこと**を
   `cabal test saas-handson`で確認する（挙動を変えない、純粋なRefactor
   ステップであることの確認）。
3. `src/User/Server.hs`のTODOを実装し、`test/unit/User/UserSpec.hs`・
   `test/integration/User/UserSpec.hs`をGREENにする。
4. `cabal run saas-handson`でサーバーを起動し、`curl`で疎通確認する
   （下記コマンド例）。

行き詰まった場合は`saas-handson-solution`の同名ファイル・ディレクトリ構成
を参照する。

```sh
cabal run saas-handson
curl http://localhost:8080/health

curl -X POST http://localhost:8080/users \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com"}'

curl http://localhost:8080/users
```

## ディレクトリ構成

現時点（Iteration 1着手前）の構成。Iteration 1の手順3完了後は
`saas-handson-solution`と同じVertical Slice構成になる。

```
src/Api.hs      Health＋UserのAPI型（今はHealthをinlineで含む暫定形）
src/Types.hs    HealthResponse（変更不要）
src/Server.hs   Healthハンドラ実装（ここを実装する）＋User分の合成
src/User/Api.hs      UserのAPI型（変更不要）
src/User/Types.hs    User, CreateUserRequest（変更不要）
src/User/Server.hs   Userハンドラ実装（ここを実装する）
app/Main.hs     エントリポイント
test/unit/          ハンドラを直接検証する単体テスト（既に用意済み）
test/integration/   WAI Application相手に検証する結合テスト（既に用意済み）
docs/           各イテレーションの設計解説
```

## 資料

- 設計パターン・ライブラリの解説：`docs/iteration-0.md`, `docs/iteration-1.md`
- 全体のロードマップ：`docs/ROADMAP.md`

行き詰まった場合は`saas-handson-solution`の同名ファイルを参照する。
