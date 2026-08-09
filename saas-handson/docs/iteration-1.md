# Iteration 1：演習

## この章で作るもの

`POST /users`（ユーザー登録）と`GET /users`（一覧取得）を実装する。データ
はDBを使わずin-memory（`IORef`）で保持する。バリデーションや重複チェック
は行わない（Iteration 5で扱う）。ユーザーは`id`・`name`・`email`のみを
持つ。あわせて、Healthを技術層別構成から機能別構成（Vertical Slice）へ
移すリファクタリングも行う。

## 進め方

演習は1-1から順に、下位（型の理解）→上位（読み取りハンドラ→書き込み
ハンドラ→テスト全体の確認）→構造のリファクタリングという順で積み上げる
構成になっている。詰まった場合は`saas-handson-solution/docs/iteration-1.md`
の対応する節、または`saas-handson-solution`の同名ファイルを参照する。
コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

## 演習1-1：User/CreateUserRequestの型を読み解く

`src/User/Types.hs`はすでに完成しており変更不要である。これを読み、
以下を自分の言葉で説明できるようにする（コードを書く必要はない）。

1. `User`は`userId`/`userName`/`userEmail`、`CreateUserRequest`は
   `crName`/`crEmail`というフィールド名を使っている。JSON上は`id`・
   `name`・`email`という素直なキー名なのに、なぜHaskell側のフィールド
   名をこのようにずらしているのか。
2. `User`の`ToJSON`/`FromJSON`はIteration 0の`HealthResponse`のように
   `deriving (Generic)`で自動導出されておらず、手書きされている。この
   違いはなぜ生じるか。
3. `userId`ではなく`id`というフィールド名をそのまま使わなかった理由の
   うち、`Prelude`に関係するものは何か。

## 演習1-2：listUsersHandlerを実装する

`src/User/Server.hs`の`listUsersHandler`を実装する。まだユーザーが
1件も登録されていない状態で、登録済みユーザーの一覧を返すだけの、最も
単純な状態操作から着手する。

- `Store`は`IORef (Int, [User])`である。次に採番するidと登録済み
  ユーザー一覧のタプルを保持している。
- `listUsersHandler`はこの`Store`から現在のユーザー一覧を読み出して
  返すだけでよい。

`cabal test saas-handson`を実行し、結合テストの「GET /usersは初期状態で
空配列を返す」がGREENになることを確認する（`createUserHandler`が未実装
のため、他のテストはまだ失敗したままでよい）。

## 演習1-3：createUserHandlerを実装する

`src/User/Server.hs`の`createUserHandler`を実装する。今度は状態を変更
する操作であり、演習1-2より1段複雑になる。

- リクエストボディ（`CreateUserRequest`）の`name`・`email`を使って新しい
  `User`を作る。idは`Store`が保持している「次に採番するid」を使い、
  使用後はカウンタを1つ進める。
- 採番とユーザー一覧への追加を、複数のリクエストが同時に来ても矛盾なく
  行えるようにする必要がある。`Data.IORef`が提供する、読み取りと書き
  換えを単一の操作として行える関数を調べて使う。

## 演習1-4：テストをすべてGREENにする

```sh
cabal test saas-handson
```

を実行し、単体テスト（`test/unit/User/UserSpec.hs`）・結合テスト
（`test/integration/User/UserSpec.hs`）のUserに関するテストがすべて
GREENになることを確認する。特に以下を確認する。

- 2件連続でユーザーを作成したとき、異なるidが採番されていること。
- `GET /users`が作成した順番どおりに一覧を返すこと。

## 演習1-5：リファクタリング（技術層別構成→機能別構成）

Iteration 0では`src/Api.hs`・`src/Server.hs`・`src/Types.hs`という技術
層別の構成だったが、これはHealthという1機能しか存在しなかったからこそ
成立していた。Userという2つ目の機能が加わった今、以下の手順でHealthを
機能別ディレクトリへ移す。挙動を変えずに構造だけを変える、Red-Green-
Refactorの「Refactor」を体験することが目的である。

1. `src/Api.hs`・`src/Server.hs`・`src/Types.hs`を、それぞれ
   `src/Health/Api.hs`・`src/Health/Server.hs`・`src/Health/Types.hs`へ
   移し、モジュール名を`Health.Api`・`Health.Server`・`Health.Types`に
   変更する。
2. `test/unit/HealthSpec.hs`・`test/integration/HealthSpec.hs`も同様に
   `test/unit/Health/HealthSpec.hs`・`test/integration/Health/HealthSpec.hs`
   へ移動し、モジュール名を`Health.HealthSpec`に変更する。
3. ルートの`src/Api.hs`・`src/Server.hs`を新規作成し、`Health.Api`・
   `Health.Server`と`User.Api`・`User.Server`をqualified importして
   `:<|>`で合成するcombinatorの形に書き換える。
4. `saas-handson.cabal`の`exposed-modules`・`other-modules`をファイル
   移動・モジュール名変更に合わせて更新する。

**この移動の前後でHealthのテスト結果が変わらないこと**を`cabal test
saas-handson`で確認する。行き詰まった場合は`saas-handson-solution`の
同名ファイル・ディレクトリ構成を参照してよい。

## 演習1-6（発展）：疎通確認と設計の一般化

1. `cabal run saas-handson`でサーバーを起動し、以下で疎通確認する。

```sh
curl http://localhost:8080/health

curl -X POST http://localhost:8080/users \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com"}'

curl http://localhost:8080/users
```

2. 演習1-5で確立した機能別構成（Vertical Slice）に、仮に3つ目の機能
   （例：`Comment`）を追加するとしたら、どのファイルを新規に作り、どの
   ファイルに1行だけ変更を加えることになるか、設計を紙またはコメントで
   書き出してみる。
3. 余力があれば、`User`に`createdAt`のような新しいフィールドを追加し、
   Red→Green→Refactorのサイクルを自力で回してみる。
