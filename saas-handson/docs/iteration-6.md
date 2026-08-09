# Iteration 6：演習

## この章で作るもの

構造化ログ（structured logging）を導入する。`POST /users`が成功・失敗
したとき、「誰が・どのテナントとして・何をした（できなかった）か」を、
機械的に検索・集計しやすい形でログに残す。

ログ出力先も、Iteration 4の`UserRepository`・Iteration 2の`JWKStore`と
同じ設計（Handleパターンによる抽象化＋DI）で扱う。`Logger`という
インターフェースに対して、標準出力へJSON行として書き出す
`Logging.Stdout`（本番用）と、メモリ上に溜めるだけの`Logging.Capturing`
（テスト用）の2つの実装を用意し、`UserRepository`をハンドラへ注入した
のと同じやり方で`Logger`も注入する。

あわせて、`wai-extra`が提供する`logStdoutDev`というミドルウェアで、
HTTPリクエスト単位のアクセスログ（メソッド・パス・ステータスコード等）
も付与する。これは「HTTPというトランスポート層で何が起きたか」を記録
するもので、`Logger`が記録する「ビジネスロジックとして何が起きたか」
（ドメインイベント）とは役割が異なる。

## 進め方

演習は6-1（型・仕組みを読み解く）→6-2（Logging.Stdoutを実装する）→6-3
（User.Serverに構造化ログを追加する）→6-4（テスト全体の確認）→6-5
（発展）という順で積み上げる。詰まった場合は
`saas-handson-solution/docs/iteration-6.md`の対応する節を参照する。
コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

## 演習6-1：型・仕組みを読み解く

以下のファイルはすでに完成しており変更不要である。これらを読み、
下記の問いに自分の言葉で答えられるようにする（コードを書く必要はない）。

- `src/Logging.hs`
- `src/Logging/Capturing.hs`

```haskell
data LogEntry = LogEntry
  { logEntryLevel   :: LogLevel
  , logEntryMessage :: Text
  , logEntryFields  :: [(Text, Text)]
  } deriving (Show, Eq)

newtype Logger = Logger
  { logEntry :: LogEntry -> IO ()
  }
```

1. `Logger`は`UserRepository`（Iteration 4）・`JWKStore`（Iteration 2）
   と同じ「レコード・オブ・関数」の形をしている。`Logging.Stdout`・
   `Logging.Capturing`という2つの実装がどちらも`IO Logger`という同じ
   型を持つことを確認し、`User.Server`（演習6-3で扱う）がこの2つの
   どちらを受け取っても動くのはなぜか説明できるようにする。
2. `LogEntry`の`logEntryMessage`は`"user_created"`のような固定の
   識別子、`logEntryFields`は`[("tenant_id", "acme"), ...]`のような
   可変の詳細情報、という役割分担になっている。仮に
   `logEntryMessage`だけで「`"テナントacmeでユーザーを作成しました"`」
   のような1つの文字列にすべて詰め込んで
   しまうと、後から「特定のテナントのログだけ検索する」といった
   作業がどう変わるか考えてみる。
3. `Logging.Capturing.newCapturingLogger`は`(Logger, IO [LogEntry])`と
   いうペアを返す。1つ目（`Logger`）をハンドラに渡し、2つ目
   （`IO [LogEntry]`）をテストコードから呼ぶことで、「ハンドラの実行
   中にどんなログが記録されたか」を検証できる。これは
   `User.Repository.InMemory`をテストで使うのとどう似ているか。

## 演習6-2：Logging.Stdoutを実装する

`src/Logging/Stdout.hs`の`writeEntry`を実装する。

```haskell
writeEntry :: LoggerSet -> LogEntry -> IO ()
writeEntry _loggerSet _entry = error "TODO: Iteration 6で実装する"
```

- `Data.Aeson.object`で、`"timestamp"`・`"level"`・`"message"`・
  `"fields"`の4フィールドを持つJSONの値を組み立てる。`"fields"`の値は
  さらに`logEntryFields`を1つのJSONオブジェクトに変換したもの
  （キーは`Data.Aeson.Key.fromText`で`Text`から`Key`へ変換する）。
- `level`には`levelText`（同じファイルに定義済み）で`LogLevel`を
  文字列化したものを使う。
- `Data.Aeson.encode`でJSONの値を`ByteString`にエンコードし、
  `System.Log.FastLogger.toLogStr`で`LogStr`に変換して
  `System.Log.FastLogger.pushLogStrLn`で書き込む。
- fast-loggerは内部でバッファリングするため、書き込み後に
  `System.Log.FastLogger.flushLogStr`を呼んで即座に出力させる
  （呼ばないと、テストや`cabal run`程度の短い実行時間ではログが標準
  出力に一切現れないことがある）。

```sh
cabal test saas-handson:test:unit --test-options='--match "Stdout"'
```

を実行し、`test/unit/Logging/StdoutSpec.hs`の3件がすべてGREENになる
ことを確認する。このテストは`silently`パッケージの`capture_`で、
実際に標準出力に書き込まれた内容を文字列として捕捉して検証している
（実行結果自体は汚さない）。

## 演習6-3：User.Serverに構造化ログを追加する

`src/User/Server.hs`の`createUserHandler`を実装する（Iteration 5から
続くTODOで、この演習でログ出力も含めてまとめて実装する）。

```haskell
createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
createUserHandler _authUser _req = error "TODO: Iteration 5/6で実装する"
```

演習5-5で実装した内容（権限チェック・メールアドレスのバリデーション）
に、以下のログ出力を追加する。

- 権限がなければ（`authRole authUser`が`Admin`でなければ）、
  `Logging.logWarn`で`"user_creation_forbidden"`というメッセージ・
  `[("tenant_id", unTenantId (authTenantId authUser)), ("subject",
  authSubject authUser)]`というfieldsでログを記録してから、
  `User.Error.Forbidden`を`throwUserError`で投げる。
- メールアドレスが不正なら、同様に`logWarn`で
  `"user_creation_invalid_email"`を記録してから、
  `User.Error.InvalidEmail`を`throwUserError`で投げる（fieldsには
  `email`も含める）。
- どちらも満たせば、Iteration 4までと同じく`UserRepository`に委譲し、
  作られた`User`の`userId`を含めて`logInfo`で`"user_created"`を記録
  する（`Data.Text.pack (show (userId newUser))`で`Int`を`Text`に
  変換できる）。

ログを記録するタイミング（権限チェック・バリデーションの失敗直後か、
成功直後か）に注目する。「何が起きたか」を、それが起きた場所のすぐ
近くで記録することで、ログを読む側が処理の流れを追いやすくなる。

## 演習6-4：テストをすべてGREENにする

```sh
cabal test saas-handson:test:unit
```

を実行し、単体テストがすべてGREENになっていることを確認する。
`test/unit/User/UserSpec.hs`に追加された、ログの内容そのものを検証する
3件（"ユーザー作成に成功するとuser_createdログが記録される"等）を含む。

```sh
cabal test saas-handson:test:integration
```

を実行し、結合テストがすべてGREENになっていることを確認する
（devcontainerのdbサービスが起動していること、`db/schema.sql`が適用
済みであることが前提）。

## 演習6-5（発展）：実サーバーでの確認・設計の一般化

1. `cabal run saas-handson`でサーバーを起動し、演習5-2の要領で
   `POST /users`を何度か叩いてみる（成功するリクエスト・Memberロール
   でのリクエスト・不正なメールアドレスのリクエストなど）。標準出力に
   2種類のログが混ざって出力されることを確認する。
   - `logStdoutDev`（wai-extra）によるアクセスログ（1行のプレーン
     テキスト、リクエストメソッド・パス・ステータスコード等）。
   - `Logging.Stdout`による構造化ログ（1行1JSON、
     `user_created`等のメッセージとfields）。
   両者を見比べて、それぞれどんな調査に向いているか（「特定の時間帯に
   エラーが多発していないか」を調べるのと、「テナントacmeのユーザーが
   最近何をしたか」を調べるのとでは、どちらのログを見るべきか）考えて
   みる。
2. 本章では`LogLevel`（`Info`・`Warn`・`Error`）を定義したが、
   実際にはすべてのログを同じように標準出力へ出力しており、レベルに
   よる出し分け（例えば本番環境では`Info`を出力しない）は行っていない。
   `Logging.Stdout`にレベルによるフィルタリングを追加するとしたら、
   `newStdoutLogger`のシグネチャをどう変えるとよいか設計してみる
   （実装は必須ではない）。
3. `listUsersHandler`（一覧取得）にはログ出力を追加していない。
   読み取り操作にもログを追加すべきかどうか、追加するとしたら
   どのような情報が有用か（毎回のアクセスを記録すると膨大な量になる
   可能性がある点も含めて）考えてみる。
4. 本章で確立した「Loggerを注入してドメインイベントを記録する」という
   パターンは、`Auth.Server`（認証成功・失敗）や
   `User.Repository.Postgres`（DBエラー発生時）にも適用できる。
   これらに広げるとしたら、どこにどんなログを追加するか設計してみる。

### 実装時に必要になるLANGUAGE拡張・依存パッケージ

| 用途 | 拡張／依存 |
|---|---|
| 標準出力への高速・スレッドセーフなログ書き込み | `fast-logger`パッケージ |
| HTTPリクエスト単位のアクセスログミドルウェア | `wai-extra`パッケージ（`Network.Wai.Middleware.RequestLogger`） |
| テストでの標準出力の捕捉 | `silently`パッケージ（`System.IO.Silently.capture_`） |
| ログのJSONエンコード（フィールドのキー変換） | `aeson`パッケージ（`Data.Aeson.Key`） |

`cabal build`・`cabal test`で「Could not load module」のようなエラーが
出た場合は、上記のいずれかが`.cabal`の`build-depends`に不足している
可能性が高い。
