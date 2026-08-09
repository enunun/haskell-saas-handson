# Iteration 6：解説

このドキュメントは`saas-handson/docs/iteration-6.md`の演習問題に対応する
解答解説である。見出しの番号（6-1〜6-5）は演習側と対応している。

## 設計判断：LoggerもDIで注入する、構造化ログ、2種類のログの役割分担

ROADMAPのIteration 6は「構造化ログ（リクエスト単位のログ、認証済み
ユーザー・テナントIDの付与、ログレベルの使い分け）の導入」「本番運用を
見据えた可観測性の確立」を目的とする。本教材では以下の方針で設計した。

1. **ログ出力先もUserRepository・JWKStoreと同じHandleパターンで抽象化
   し、DIで注入する。** `Logger`という「インターフェース」
   （`data Logger = Logger { logEntry :: LogEntry -> IO () }`）に対し、
   `Logging.Stdout`（本番用、標準出力へJSON行を書く）・
   `Logging.Capturing`（テスト用、メモリに溜める）という2つの実装を
   用意した。これはIteration 4・5で確立したDIパターンを、新しい横断的
   関心事（ロギング）に対してもそのまま適用できることを示している。
2. **構造化ログ（structured logging）として設計する。** `LogEntry`は
   固定のメッセージ識別子（`logEntryMessage`）と、可変の詳細情報
   （`logEntryFields`、キー・バリューのリスト）を分離して持つ。
   `printf`スタイルの「文字列に値を埋め込んだ1行のログ」と異なり、
   構造化ログは「`message = "user_created"`のログをすべて集計する」
   「`tenant_id = "acme"`のログだけ抽出する」といった機械的な検索・
   集計がしやすい。
3. **アクセスログ（HTTPトランスポート層）とドメインログ
   （ビジネスロジック層）を分けて考える。** `wai-extra`の
   `logStdoutDev`はHTTPリクエスト単位で「メソッド・パス・ステータス
   コード」を記録する、既製のミドルウェアである。これは車輪の再発明を
   避けるべき典型例であり、自作していない。一方、「どのテナントの
   誰が、ユーザー作成に成功・失敗したか」というビジネス上の意味を
   持つ情報は、HTTPの外側（Servantのルーティングより後、
   `AuthenticatedUser`が手に入った後）でしか記録できないため、
   `User.Server`の中で明示的に`Logger`を呼ぶ必要がある。この2つは
   同じ「ログ」という言葉で呼ばれるが、記録される場所・タイミング・
   目的が異なる。

## 演習6-1の解説：型・仕組みを読み解く

### `Logger`はUserRepository・JWKStoreと同じ形をしている

```haskell
newtype Logger = Logger
  { logEntry :: LogEntry -> IO ()
  }
```

`UserRepository`は`createUser`・`listUsers`という2つの操作を持つ
レコードだったが、`Logger`は`logEntry`という1つの操作しか持たない、
より単純な例である。`newStdoutLogger :: IO Logger`・
`newCapturingLogger :: IO (Logger, IO [LogEntry])`はどちらも
（`Logger`部分に関しては）同じ型の値を作る関数であり、`User.Server`の
`server`関数はどちらが渡されても、渡された`Logger`の`logEntry`を呼ぶ
だけなので問題なく動く。これは「`server`が`Logger`という抽象化された
インターフェースにしか依存していない」ことの帰結であり、Iteration 4の
`UserRepository`について解説したのと全く同じ理由（依存性逆転の原則）
による。

### メッセージとフィールドを分離する理由

`logEntryMessage`（固定の識別子）と`logEntryFields`（可変の詳細情報）を
分けることで、ログを機械的に処理しやすくなる。例えば「`message =
"user_created"`のログの件数を1時間ごとに集計してユーザー登録数の推移を
見る」「`fields`の`tenant_id`が`"acme"`のログだけを抽出してそのテナント
の操作履歴を追う」といった処理は、両者が構造として分離されているから
こそ機械的に行える。仮に`"テナントacmeでユーザーを作成しました"`の
ような1つの文字列にすべて詰め込んでしまうと、こうした集計・抽出のたび
に文字列パース（正規表現等）が必要になり、ログの形式が少し変わるだけで
壊れやすい。

### `Logging.Capturing`とテストの関係

```haskell
newCapturingLogger :: IO (Logger, IO [LogEntry])
```

このペアの1つ目（`Logger`）をハンドラに注入し、2つ目
（`IO [LogEntry]`）をテストコードから呼ぶ、という構造は、
`User.Repository.InMemory`が「テスト用の実装を注入して、実DBなしで
ハンドラの振る舞いを検証する」のと同じ狙いを持つ。違いは、
`UserRepository`が「注入した状態を読み書きする」ものだったのに対し、
`Logger`は「注入した先で何が呼ばれたかを後から観測する」ものである点
である（Repositoryは状態そのもの、Loggerは副作用の記録、という違い）。

## 演習6-2の解説：Logging.Stdoutを実装する

```haskell
writeEntry :: LoggerSet -> LogEntry -> IO ()
writeEntry loggerSet entry = do
  now <- getCurrentTime
  let json = object
        [ "timestamp" .= formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%QZ" now
        , "level" .= levelText (logEntryLevel entry)
        , "message" .= logEntryMessage entry
        , "fields" .= object [Key.fromText k .= String v | (k, v) <- logEntryFields entry]
        ]
  pushLogStrLn loggerSet (toLogStr (encode json))
  flushLogStr loggerSet
```

### なぜ`putStrLn`ではなく`fast-logger`を使うのか

Warpは各HTTPリクエストを別々のHaskellスレッドで処理する。複数の
リクエストがほぼ同時に来て、それぞれが`System.IO.putStrLn`で直接標準
出力に書き込むと、OSレベルのバッファリングの都合で複数行の出力が
文字単位で混ざってしまう（interleaveされる）ことがある。`fast-logger`
の`LoggerSet`はこの問題を避けつつ高速に書き込めるよう設計された
ライブラリであり、`pushLogStrLn`は1回の呼び出しで1行分の出力が丸ごと
書き込まれることを保証する。

### `flushLogStr`が必要な理由

`fast-logger`は内部にバッファを持ち、バッファが一定量溜まるか明示的に
flushされるまでは実際のファイルディスクリプタへの書き込みを遅延させる
（これがまさに高速である理由の1つである）。`cabal run`で立てた
サーバーをすぐに`curl`で叩いて標準出力を確認する、あるいはテストの中で
`capture_`を使って出力を捕捉する、といった短命な検証では、バッファが
自然に溜まりきる前にプロセス・アクションが終わってしまい、ログが
一切見えないことがある。`writeEntry`の中で書き込みのたびに
`flushLogStr`を呼ぶことで、この問題を避けている（高スループットな
本番運用ではこれがオーバーヘッドになりうるため、バッファリングを
活かしたい場合は書き込み頻度を落とす設計もありうるが、本教材では
確実に見える方を優先した）。

### テストでの検証（`silently`）

```haskell
it "level・message・fieldsを含むJSONを出力する" $ do
  output <- capture_ $ do
    logger <- newStdoutLogger
    logWarn logger "user_creation_forbidden" [("tenant_id", "acme"), ("subject", "bob")]
  output `shouldContain` "\"level\":\"warn\""
  ...
```

`silently`の`capture_ :: IO a -> IO String`は、渡した`IO`アクションの
実行中に標準出力へ書かれた内容をまるごと`String`として返す（実際の
標準出力には流さない）。これにより、`Logging.Stdout`が本当に標準出力へ
書き込む実装であるにもかかわらず、テストの実行結果を汚さずに出力内容を
検証できる。

## 演習6-3の解説：User.Serverに構造化ログを追加する

```haskell
createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
createUserHandler authUser (CreateUserRequest reqName reqEmail)
  | authRole authUser /= Admin = do
      liftIO $ logWarn logger "user_creation_forbidden"
        [ ("tenant_id", unTenantId (authTenantId authUser))
        , ("subject", authSubject authUser)
        ]
      throwUserError Forbidden
  | not (isValidEmail reqEmail) = do
      liftIO $ logWarn logger "user_creation_invalid_email"
        [ ("tenant_id", unTenantId (authTenantId authUser))
        , ("subject", authSubject authUser)
        , ("email", reqEmail)
        ]
      throwUserError (InvalidEmail reqEmail)
  | otherwise = do
      newUser <- liftIO (createUser repo (authTenantId authUser) reqName reqEmail)
      liftIO $ logInfo logger "user_created"
        [ ("tenant_id", unTenantId (authTenantId authUser))
        , ("subject", authSubject authUser)
        , ("user_id", Text.pack (show (userId newUser)))
        ]
      pure newUser
```

権限チェック・バリデーションの失敗と、作成成功は、いずれも「その場で
何が起きたか」をその直後にログへ記録してから、次の処理（エラーを
投げる、または結果を返す）に進んでいる。これにより、ログを時系列で
読むだけで「いつ・誰が・何をしようとして・どうなったか」を追える。
`Forbidden`・`InvalidEmail`は`Warn`レベル（想定内の失敗、異常ではないが
注意を要する）、`user_created`は`Info`レベル（正常な処理結果）とした。
ログレベルの使い分けにより、後から「警告以上のログだけを見る」といった
絞り込みができる。

## 演習6-4の解説：テストをすべてGREENにする

```haskell
it "ユーザー作成に成功するとuser_createdログが記録される" $ do
  repo <- newInMemoryUserRepository
  (logger, getLogs) <- newCapturingLogger
  let create :<|> _list = server logger repo
  Right created <- runHandler (create testUser (CreateUserRequest "Alice" "alice@example.com"))
  logs <- getLogs
  logs `shouldBe`
    [ LogEntry Info "user_created"
        [ ("tenant_id", "acme")
        , ("subject", "test-user")
        , ("user_id", "1")
        ]
    ]
```

このテストは、`createUserHandler`が単に正しい`User`を返すだけでなく、
「意図したとおりのログを、意図したとおりの内容で」記録したことまでを
検証している。`Logging.Capturing`が返す`getLogs`はハンドラ実行中に
記録された`LogEntry`のリストをそのまま返すため、`LogEntry`の
`Eq`インスタンス（`deriving (Show, Eq)`）を使って期待値と直接比較
できる。これにより、「ログを追加し忘れた」「メッセージ文字列を
間違えた」「fieldsに必要な情報を含め忘れた」といった不備を、
Handlerの戻り値の検証とは独立に検出できる。

## 演習6-5の解説（発展）：実サーバーでの確認・設計の一般化

### アクセスログとドメインログの使い分け

`logStdoutDev`によるアクセスログは「HTTPレベルで何が起きたか」
（どのパスに何回リクエストが来たか、レスポンスタイムはどうか、
ステータスコードの分布はどうか）を横断的に把握するのに向いている。
`Logging.Stdout`によるドメインログは「ビジネス上の意味のある出来事」
（誰がいつユーザーを作成したか、権限エラーがどのテナントで多発して
いるか）を追跡するのに向いている。実務では前者をインフラ・SRE寄りの
監視（Datadog、Grafana等のダッシュボード）に、後者を監査ログや
ビジネス分析に使うことが多い。

### ログレベルによるフィルタリング

現状の`Logging.Stdout`はレベルにかかわらずすべてのログを出力する。
レベルによるフィルタリングを追加するとしたら、
`newStdoutLogger :: LogLevel -> IO Logger`のように最小出力レベルを
引数に取るようにし、`writeEntry`の中で`logEntryLevel entry`が
指定した最小レベル未満なら何もしない、という設計が考えられる
（`LogLevel`に`Ord`インスタンスを導出すれば`>=`で比較できる）。

### Iteration 3〜5で確立した型をログに接続する

本章の`logInfo`・`logWarn`の呼び出しで使っている`authTenantId`・
`authSubject`（Iteration 3）、`Forbidden`・`InvalidEmail`
（Iteration 5）は、いずれも過去のIterationで導入した型である。
ロギングという新しい関心事を追加する際に、既存の型（
`AuthenticatedUser`・`UserError`）を素通りせず活用できたのは、
これらの型が最初から「誰が」「何が」を表現する明確な構造を持って
いたからである。型で表現された情報は、認可判定・エラーレスポンス・
ログ出力など、複数の目的に再利用できる。
