# Iteration 6：解説

このドキュメントは`../../exercise/docs/iteration-6.md`の演習問題に対応する
解答解説である。見出しの番号（6-1〜6-9）は演習側と対応している。

## 演習6-1の解説：Logging層を読み解く

### 構造化ログ

```haskell
-- src/Logging.hs
data LogEntry = LogEntry
  { logEntryLevel   :: LogLevel
  , logEntryMessage :: Text
  , logEntryFields  :: [(Text, Text)]
  }
```

`message`を"user_created"のような固定の識別子にし、可変の詳細
（誰が・どのテナントか等）を`fields`として分離すると、ログを後から
機械的に検索・集計しやすくなる（例：「`message`が"user_created"の件数
を`tenant_id`ごとに集計する」）。1本の文字列に値を埋め込む
（`printf`スタイルの）ログは人が読むには自然だが、値の位置や形式が
ログ出力のたびに微妙に変わりうり、機械的な処理には向かない。

### Handleパターンの使い回し

`Logger`は`UserRepository`と全く同じ形（関数を1つ以上持つレコード）で
表現されている。これにより、本番は`Logging.Stdout`、テストは
`Logging.Capturing`という差し替えが、`UserRepository`のときと同じ
やり方（値として組み立てて引数で渡すだけ）で実現できる。

### fast-loggerとLoggerSet

複数のリクエストスレッドが同時に生の`putStrLn`を呼ぶと、1行の途中で
別のスレッドの出力が割り込み、複数行が混ざってしまうことがある
（interleave）。fast-loggerの`LoggerSet`は、複数スレッドから同時に
書き込まれても1行の出力が混ざらないことを保証しつつ高速に書き込める
ように設計されている。

### `System.IO.Silently`の`capture_`

`capture_ action`は、`action`の実行中に標準出力へ書き込まれた内容を
文字列として捕捉し、実際の標準出力には出力しない。これにより、
「標準出力に何を書き込んだか」をテストのアサーションとして直接
検証できる（テスト実行時のログ出力でテスト結果自体が読みにくくなる
ことも防げる）。

## 演習6-2の解説：Logging.Capturingを完成させる

```haskell
-- src/Logging/Capturing.hs
newCapturingLogger :: IO (Logger, IO [LogEntry])
newCapturingLogger = do
  entriesVar <- newMVar []
  let logger = Logger { logEntry = \e -> modifyMVar_ entriesVar (\es -> pure (es ++ [e])) }
  pure (logger, readMVar entriesVar)
```

`User.Repository.InMemory`が`IORef`＋`atomicModifyIORef'`を使ったのに
対し、ここでは`MVar`＋`modifyMVar_`を使っている。どちらも「複数の
書き込みが競合しても状態が壊れない」ことを保証する道具である
（`MVar`は「空か、値が1つ入っているかの箱」で、`modifyMVar_`は
「取り出す→計算する→戻す」を1つの操作として保証する）。戻り値の
2つ目`readMVar entriesVar`は、呼ぶたびにその時点の内容を返す
`IO [LogEntry]`になる。

## 演習6-3の解説：User.ServerにLoggerを配線する

`server`の型に`Logger`引数を追加するだけで、ハンドラの中身はまだ
変更しない。型を先に変えてから中身を埋めるこの順番により、演習6-4で
「型は合っているが、まだ何もログを出していない」という中間状態を経由
できる。

## 演習6-4の解説：既存のテストを直す

`User.Server.server`が`Logger`を追加で受け取るようになったため、
これを呼び出すすべてのテストコードで`Logging.Capturing.newCapturingLogger`
を使ってテスト用の`Logger`を用意し、渡す必要がある。振る舞い自体は
変わらないので、既存のアサーションは変更しなくてよい。

## 演習6-5の解説：権限不足のログを検証する

```haskell
-- test/unit/User/UserSpec.hs
it "memberがPOST /usersを呼ぶと403相当（Forbidden）になり、警告ログが記録される" $ do
  repo <- newInMemoryUserRepository
  (logger, getLogs) <- newCapturingLogger
  let createUserHandler :<|> _ :<|> _ = server logger repo
  result <- runHandler (createUserHandler acmeMember (CreateUserRequest "Alice" "alice@example.com"))
  ...
  logs <- getLogs
  map logEntryMessage logs `shouldBe` ["user_creation_forbidden"]
  map logEntryLevel logs `shouldBe` [Warn]
```

`newCapturingLogger`が返す2つ目の値（`getLogs :: IO [LogEntry]`）を
ハンドラ呼び出しの**後**に呼ぶことで、その時点までに記録された
ログをすべて取得できる。演習6-3の時点ではどこも`logEntry`を呼んで
いないため、このテストはまずREDになる。

```haskell
-- src/User/Server.hs
createUserHandler authUser req
  | authRole authUser /= Admin = do
      liftIO (logWarn logger "user_creation_forbidden"
        [("tenant_id", unTenantId (authTenantId authUser)), ("subject", authSubject authUser)])
      throwUserError Forbidden
  | ...
```

権限不足の分岐に`logWarn`を1つ追加するとGREENになる。「誰が・どの
テナントとして・何ができなかったか」というIteration 2・3で確立した
情報（`authSubject`・`authTenantId`）が、ここで初めてログという運用時
のアウトプットに接続される。

## 演習6-6の解説：残り2つのログ呼び出しを追加する

演習6-5と全く同じパターンで、メール形式不正の分岐に`logWarn`、成功時の
分岐に`logInfo`を追加する。

```haskell
-- src/User/Server.hs
createUserHandler authUser req
  | authRole authUser /= Admin = do
      liftIO (logWarn logger "user_creation_forbidden" [...])
      throwUserError Forbidden
  | not (isValidEmail (crEmail req)) = do
      liftIO (logWarn logger "user_creation_invalid_email" [...])
      throwUserError (InvalidEmail (crEmail req))
  | otherwise = do
      newUser <- liftIO (createUser repo (authTenantId authUser) (crName req) (crEmail req))
      liftIO (logInfo logger "user_created"
        [("tenant_id", unTenantId (authTenantId authUser)), ("subject", authSubject authUser)
        , ("user_id", Text.pack (show (userId newUser)))])
      pure newUser
```

## 演習6-7の解説：wai-extraのアクセスログ

```haskell
-- app/Main.hs
run 8080 (logStdoutDev (mkApp jwkStore logger repo))
```

`logStdoutDev`はWAIミドルウェアで、`Application`を受け取り、リクエスト
ごとにメソッド・パス・ステータスコード等を標準出力へ記録する
`Application`でラップして返す。`mkApp`自体（＝ドメインロジック）は
一切変更する必要がない。ミドルウェアという仕組みにより、「HTTPと
いうトランスポート層の出来事を記録する」という横断的関心事を、
アプリケーションのコードに一切触れずに追加できている。

## 演習6-8の解説：単体テスト・結合テストへの影響を考える

問い1の答え：`logStdoutDev`（アクセスログ）はHTTPというプロトコルの
レベルで「どのメソッド・パスに、何秒かけて、何ステータスで応答した
か」を記録する。リクエストの中身がドメイン的に何を意味するかは
知らない。`User.Server`が呼ぶ`Logger`（ドメインログ）は逆に、HTTPの
詳細（ヘッダやステータスコード）を一切記録せず、「どのテナントの
誰が、ユーザー作成に成功した／権限不足で失敗した」というドメインの
出来事だけを記録する。両方を組み合わせることで、運用時に「HTTPレベル
で何が起きたか」と「ビジネスロジックとして何が起きたか」の両方を
追跡できる。

問い2の答え：`Logging.Capturing`・`User.Repository.InMemory`・
`Auth.Server.mkJWKStore`の3つはいずれも、「本番用の実装（実DB・実
ネットワーク・実標準出力）が持つ副作用や依存を持たず、代わりに
メモリ上の状態や既知の値をその場で使う」という設計で作られている。
これにより、単体テスト・結合テストの一部が、外部サービス（DB・
認証サーバー）や実際の標準出力に一切依存せずに、高速かつ決定的に
実行できる。

## 使用ライブラリ

| ライブラリ | 役割 |
|---|---|
| fast-logger | 複数スレッドから安全に標準出力へ書き込む（`Logging.Stdout`） |
| wai-extra | HTTPアクセスログミドルウェア（`logStdoutDev`） |
