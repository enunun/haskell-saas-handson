# Iteration 6：演習

## この章で作るもの

構造化ログ（リクエスト単位のログ、認証済みユーザー・テナントIDの付与、
ログレベルの使い分け）を導入する。`Logger`を`UserRepository`・
`JWKStore`と同じHandleパターンで注入し、`Logging.Stdout`（本番、
fast-loggerでJSON行を標準出力へ）・`Logging.Capturing`（テスト、
メモリに記録）の2実装を用意する。あわせて`wai-extra`のアクセスログ
ミドルウェアも導入する。

`src/Logging.hs`（インターフェース）・`src/Logging/Stdout.hs`
（本番実装）はすでに完成している（fast-loggerの使い方自体は本教材の
主題ではないため、既存の実装を読んで理解する形にしている）。この章の
演習は、テスト用実装（`Logging.Capturing`）を完成させ、`User.Server`に
ログ出力を接続することが中心になる。

## 進め方

演習は6-1から順に取り組む。詰まった場合は`../solution/docs/iteration-6.md`
の対応する節を読む。コマンドはリポジトリルート（`cabal.project`のある
場所）から実行する。

## 演習6-1：Logging層を読み解く

`src/Logging.hs`・`src/Logging/Stdout.hs`・
`test/unit/Logging/StdoutSpec.hs`を読み、以下を自分の言葉で説明できる
ようにする（コードを書く必要はない）。

1. `LogEntry`は`message`（固定の識別子）と`fields`（可変の詳細）を
   分けて持つ。これがなぜ「構造化ログ」と呼ばれるか、
   `printf`スタイルの1本の文字列に全部を埋め込むログと比較して説明
   する。
2. `Logger`は`UserRepository`と同じレコード・オブ・関数（Handle
   パターン）で表現されている。この設計をここでも使う利点を、
   本番用（`Stdout`）とテスト用（後で作る`Capturing`）を差し替える
   場面から説明する。
3. `newStdoutLogger`は`fast-logger`の`LoggerSet`を使っている。生の
   `putStrLn`を複数のリクエストスレッドから直接呼んだ場合と比べて、
   何が違うか。
4. `test/unit/Logging/StdoutSpec.hs`は`System.IO.Silently`の`capture_`
   を使っている。この関数がテストにとってどう役立っているか。

## 演習6-2：Logging.Capturingを完成させる（Green）

`src/Logging/Capturing.hs`の`newCapturingLogger`はまだ
`error "TODO: ..."`のままである。`Control.Concurrent.MVar`を使って
実装する（`src/Logging/Capturing.hs`のヒントを参照）。

## 演習6-3：User.ServerにLoggerを配線する（まだログは呼ばない）

1. `src/User/Server.hs`の`server`の型を`Logger -> UserRepository ->
   Server API`に変更し、`Logger`を最初の引数として受け取るようにする
   （ハンドラの中身はまだ変更しない）。
2. `src/Server.hs`の`mkServer`・`mkApp`を、`Logger`を受け取って
   `User.server`にそのまま渡す形に変更する。

## 演習6-4：既存のテストを直す

`src/User/Server.hs`の`server`の引数が増えたため、既存の
`test/unit/User/UserSpec.hs`・`test/integration/User/UserSpec.hs`は
コンパイルエラーになる。`Logging.Capturing.newCapturingLogger`で
テスト用の`Logger`を用意し、`server`を呼ぶすべての箇所に渡すように
書き換える。

```sh
cabal test saas-handson-iteration6:test:unit saas-handson-iteration6:test:integration
```

を実行し、GREENに戻ることを確認する（ログはまだ何も出力していないので、
振る舞い自体は変わっていない）。

## 演習6-5：権限不足のログを検証する（Red→Green）

1. `test/unit/User/UserSpec.hs`の「memberがPOST /usersを呼ぶと403相当
   （Forbidden）になる」テストを拡張し、`newCapturingLogger`が返す
   `IO [LogEntry]`を使って、`user_creation_forbidden`という`message`・
   `Warn`という`logEntryLevel`のログが1件記録されていることも検証する。
2. REDになることを確認する（まだどこも`logEntry`を呼んでいないため）。
3. `createUserHandler`の権限不足の分岐に、
   `logWarn logger "user_creation_forbidden"`（`tenant_id`・`subject`を
   `fields`として渡す）を追加し、GREENにする。

## 演習6-6：残り2つのログ呼び出しを追加する

演習6-5で確立したパターンに従い、`createUserHandler`の残り2つの分岐にも
ログ呼び出しを追加する。

- メール形式不正：`logWarn logger "user_creation_invalid_email"`に、
  `tenant_id`・`subject`・`email`を渡す。
- 成功：`logInfo logger "user_created"`に、`tenant_id`・`subject`・
  `user_id`（`Data.Text.pack (show (userId newUser))`で`Int`を`Text`に
  変換する）を渡す。

余裕があれば、演習6-5と同じ要領でこの2つについてもログの記録を検証する
テストを先に書いてからログ呼び出しを追加してみる。

## 演習6-7：wai-extraのアクセスログを導入する

`app/Main.hs`で、`Logging.Stdout.newStdoutLogger`でLoggerを作り、
`mkApp`に渡すように変更する。さらに`Network.Wai.Middleware.RequestLogger`
の`logStdoutDev`で、サーバー全体をラップする
（`run 8080 (logStdoutDev (mkApp jwkStore logger repo))`）。

## 演習6-8：単体テスト・結合テストへの影響を考える

1. `logStdoutDev`（HTTPアクセスログ）と`User.Server`が呼ぶ`Logger`
   （ドメインログ）は、どちらも「何が起きたか」を記録する点は同じ
   だが、記録する内容の抽象度が異なる。それぞれ何を記録し、何を
   記録しないかを説明する。
2. `Logging.Capturing`は、`User.Repository.InMemory`・
   `Auth.Server.mkJWKStore`と同じ狙いで作られている。この3つに共通する
   設計方針を、一言でまとめる。

## 演習6-9（発展）：疎通確認

```sh
cabal run saas-handson-iteration6
```

でサーバーを起動し、`docs/iteration-5.md`の疎通確認と同じ手順で
リクエストを送る。標準出力に、`wai-extra`によるHTTPアクセスログと、
`Logging.Stdout`による構造化ドメインログ（`user_created`等、1行1JSON）
の両方が出力されることを確認する。
