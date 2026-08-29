# Iteration 1：演習

## この章で作るもの

ユーザーリソースのCRUDを、永続化を伴わない最小構成（メモリ内のみ）で
構築する。`POST /users`（登録）・`GET /users`（一覧）・
`GET /users/{id}`（単一取得。存在しないidは404）の3エンドポイントを
追加する。

機能がHealth・Userの2つになるタイミングで、`src/Api.hs`・`Server.hs`・
`Types.hs`という技術層別構成から、機能ごとにディレクトリを分ける
Vertical Slice構成（`src/Health/`・`src/User/`）へ移行する
リファクタリングも行う。

## 進め方

演習は1-1から順に取り組む。詰まった場合は`../solution/docs/iteration-1.md`
の対応する節を読む。コマンドはリポジトリルート（`cabal.project`のある
場所）から実行する。

## 演習1-1：Userの型・APIを読み解く

`src/User/Types.hs`・`src/User/Api.hs`・`src/User/Store.hs`を読み、
以下を自分の言葉で説明できるようにする（コードを書く必要はない）。

1. `User`は`userId`・`userName`・`userEmail`、`CreateUserRequest`は
   `crName`・`crEmail`というフィールド名を持つ。なぜ両方とも素直に
   `name`・`email`という名前にしなかったのか。
2. `CreateUserRequest`の`FromJSON`インスタンスは`deriving`ではなく
   `withObject`・`.:`を使って手書きされている。`deriving (Generic)`
   だけで済ませられない理由を、フィールド名とJSONキーの対応関係から
   説明する。
3. `type API = "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated
   '[JSON] User :<|> ...`という型から、それぞれのエンドポイントの
   HTTPメソッド・パス・リクエストボディ・レスポンスの内容形式を読み取る。
4. `User.Store`の`createUser`は`atomicModifyIORef'`を使っている。
   `readIORef`で読んで`writeIORef`で書き戻す2ステップに分けて実装
   すると何が問題になるか（複数のリクエストが同時に来る場合を考える）。

`src/User/Server.hs`の3つのハンドラはまだ`error "TODO: ..."`のままで
ある。以降の演習1-2〜1-6では、1つのテストを書いて失敗（Red）を確認し、
それを通す最小限の実装を書いて成功（Green）させる、というサイクルを
振る舞いの単位ごとに繰り返す。一度にすべてのテストを書いてから実装を
まとめて書く、という進め方はしない（実装量がまだ小さいため、Greenに
したコードを見直すリファクタリングの工程は省略してよい）。

`test/unit/User/UserSpec.hs`を新規作成する（`test/unit/HealthSpec.hs`が
`Health.Server.server`を直接呼び出しているのと同じ要領で、
`User.Server.server`を直接呼び出す。ただし`Store`を引数に取るので、
各テストで`User.Store.newStore`を呼んで新しい`Store`を用意する）。
`saas-handson-iteration1.cabal`の`test-suite unit`の`other-modules`に
`User.UserSpec`を追記しておく。

## 演習1-2：ユーザーを1人作成する（Red→Green）

1. 「ユーザーを1人作成すると、id=1が採番されて返る」ことだけを検証する
   テストを1つ書く。
2. `cabal test saas-handson-iteration1:test:unit`を実行し、このテスト
   だけがREDになることを確認する。
3. `src/User/Server.hs`の`createUserHandler`を実装し（`User.Store`に
   委譲するだけでよい）、GREENにする。

## 演習1-3：2人目のユーザーを作成する（Red→Green）

1. 「続けてもう1人作成すると、id=2が採番される」ことを検証するテストを
   追加する。
2. REDになることを確認する（あるいは、演習1-2の実装がすでにこの
   ケースにも対応していてGREENのままかもしれない。どちらであっても、
   その理由を`src/User/Store.hs`の実装から説明できるようにする）。
3. REDだった場合は実装を直し、GREENにする。

## 演習1-4：一覧取得（Red→Green）

1. 「作成済みユーザーが`GET /users`相当のハンドラで一覧として返る」
   ことを検証するテストを追加する。REDになることを確認する。
2. `listUsersHandler`を実装し、GREENにする。

## 演習1-5：単一取得・成功（Red→Green）

1. 「作成済みユーザーのidで取得すると、そのユーザーが返る」ことを
   検証するテストを追加する。REDになることを確認する。
2. `getUserHandler`を実装し、GREENにする。

## 演習1-6：単一取得・404（Red→Green）

1. 「存在しないidで取得すると、`servant`の`err404`相当のエラーが返る」
   ことを検証するテストを追加する。REDになることを確認する。
2. `getUserHandler`を拡張し、GREENにする。

## 演習1-7：結合テストで同じ振る舞いを確認する

`test/integration/User/UserSpec.hs`を新規作成し、`User.Api.API`だけ
からApplicationを組み立てて（`test/integration/HealthSpec.hs`と同じ
要領）、演習1-2〜1-6ですでに実装した振る舞いをHTTP経由で検証する
テストを書く。

- `POST /users`に`{"name":"Alice","email":"alice@example.com"}`を
  送ると、201と`{"id":1,"name":"Alice","email":"alice@example.com"}`
  が返る。
- その後`GET /users`を叩くと、作成したユーザーを含む配列が返る。
- `GET /users/1`を叩くと、そのユーザーが返る。
- `GET /users/999`を叩くと404が返る。

`saas-handson-iteration1.cabal`の`test-suite integration`の
`other-modules`に`User.UserSpec`を追記する。

```sh
cabal test saas-handson-iteration1:test:integration
```

を実行する。ハンドラの実装はすでに完成しているため、これらのテストは
書いた時点でGREENになるはずである（もしREDになった場合は、単体テスト
では検証していなかった層——ルーティングやJSONのフィールド名——に
問題がある可能性が高い）。

## 演習1-8：Vertical Sliceへのリファクタリング

機能がHealth・Userの2つになったので、技術層別構成から機能別構成へ
移行する。

1. `src/Health/`ディレクトリを作り、`src/Api.hs`・`Server.hs`・
   `Types.hs`の中身をそれぞれ`src/Health/Api.hs`・`Health/Server.hs`・
   `Health/Types.hs`に移し、モジュール名を`Health.Api`・
   `Health.Server`・`Health.Types`に変更する（`Health.Api`は`API`型
   のみをエクスポートすればよく、`Proxy`は不要になる）。
2. 新しい`src/Api.hs`を、`Health.Api`・`User.Api`をqualified importして
   `type API = Health.API :<|> User.API`とする形に書き換える
   （`TypeApplications`ではなく`TypeOperators`が`:<|>`に必要）。
3. 新しい`src/Server.hs`を、`mkServer store = Health.server :<|>
   User.server store`・`mkApp store = serve api (mkServer store)`という
   形に書き換える。
4. `app/Main.hs`で`User.Store.newStore`を呼んで`Store`を作り、
   `mkApp`に渡すように変更する。
5. `saas-handson-iteration1.cabal`の`library`の`exposed-modules`を
   新しいモジュール名（`Health.Api`・`Health.Server`・`Health.Types`）
   に更新する。
6. `test/unit/HealthSpec.hs`・`test/integration/HealthSpec.hs`を、
   `Health.Server`・`Health.Api`を直接使う形に書き換える（演習1-2〜1-7で
   `User.UserSpec`をすでにこの形で書いているはずなので、同じパターンを
   Healthにも適用する）。

```sh
cabal test saas-handson-iteration1
```

を実行し、Health・Userのテストが両方ともGREENのままであることを確認
する（振る舞いを変えないリファクタリングなので、テストの結果は
変わらないはずである）。

## 演習1-9：単体テスト・結合テストへの影響を考える

演習1-8のリファクタリングで、`test/unit/HealthSpec.hs`・
`test/integration/HealthSpec.hs`は編集が必要だったが、Health自体の
振る舞い（`GET /health`が返す内容）は一切変えていない。

1. なぜHealthの振る舞いを変えていないのに、Healthのテストを編集する
   必要があったのか。
2. 単体テスト・結合テストのどちらも同じ理由で編集が必要だったか。
   それぞれのテストがそれまで何を呼び出していて、リファクタリング後は
   何を呼び出すようになったかを比較して答える。
3. もし`User.Server.server`がUser機能以外の状態（例えばHealthの状態）
   に一切触れていなかったとしたら、この編集は本当に必要だったか。
   Vertical Slice構成の狙いと関連付けて説明する。

## 演習1-10（発展）：メールアドレスの重複を禁止する

同じメールアドレスで2人目のユーザーを作成しようとした場合に、
作成を拒否するようにする。

1. まずテストを書き、REDになることを確認する（2人目の作成が失敗する
   ことを検証する。エラーの返し方は自由に決めてよい）。
2. `User.Store`・`User.Server`を変更し、GREENにする。
3. 実装を見直し、テストがGREENのままリファクタリングする。
