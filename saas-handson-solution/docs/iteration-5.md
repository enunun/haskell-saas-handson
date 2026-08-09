# Iteration 5：解説

このドキュメントは`saas-handson/docs/iteration-5.md`の演習問題に対応する
解答解説である。見出しの番号（5-1〜5-7）は演習側と対応している。

## 設計判断：認可はハンドラの中で、エラーは型で表現する

ROADMAPのIteration 5は「ドメインエラー型の設計と、Servantでの表現
（HTTPステータスコードへのマッピングを含む）」「ユーザーの権限に応じた
アクセス制御」を目的とする。本教材では以下の方針で設計した。

1. **ロールはJWTの`role`クレームとして受け取る。** Iteration 3の
   `tenant_id`と同じ設計思想で、認証サーバー（本教材では
   mock-oauth2-server）がロールを検証した上でクレーム発行する、という
   責務分担を前提にしている。
2. **認証と認可を明確に分離する。** 認証（このリクエストは誰からのもの
   か）はIteration 2で確立した`AuthProtect "jwt"`が担い、Servantの
   ルーティング解決の一部としてハンドラ本体より先に走る。認可
   （その人はこの操作をしてよいか）はハンドラ本体のドメインロジックと
   して書く。この分離により、401（未認証）と403（認証済みだが権限
   なし）という異なる意味のHTTPステータスコードが、コード上でも異なる
   層から発生するようになる。
3. **ドメインエラーはHTTPの語彙から独立した型（`UserError`）として
   表現し、HTTPへの変換を1箇所に集約する。** `UserError`自体は
   `err403`や`err400`といったServant・HTTPの型を一切知らない。
   `User.Error.toServerError`という1つの関数だけが「`UserError`の
   どの値がどのHTTPステータスコードに対応するか」を知っている。
   これにより、「新しい種類のエラーを追加したときにHTTPステータス
   コードへの対応付けを書き忘れる」というクラスのミスが起こりにくく
   なる（`toServerError`の網羅性を型検査で確認できる。実際、
   `UserError`にコンストラクタを追加すると`toServerError`の
   パターンマッチが非網羅的になり、`-Wincomplete-patterns`が有効なら
   警告が出る）。

## 演習5-1の解説：型・仕組みを読み解く

### `Role`の`FromJSON`が`fail`したときの挙動

```haskell
instance FromJSON Role where
  parseJSON = withText "Role" $ \t -> case t of
    "admin"  -> pure Admin
    "member" -> pure Member
    other    -> fail ("unknown role: " ++ show other)
```

`AuthClaims`の`FromJSON`インスタンス（`Auth.Server`）は
`o .: "role"`でこの`FromJSON Role`インスタンスを呼び出す。ここで
`fail`が呼ばれると、`AuthClaims`全体のパースが失敗し、それは
`verifyJWT`が投げる`JWTClaimsSetDecodeError`として観測される
（`Crypto.JWT.verifyJWT`の実装は、ペイロードのデコードに
`eitherDecode`を使い、失敗を`_JWTClaimsSetDecodeError`として
`throwing`している）。これは`tenant_id`クレームが欠落している場合と
全く同じ失敗経路であり、`Auth.AuthSpec`の「tenant_idクレームがない
トークンは拒否される」「roleクレームがないトークンは拒否される」
「roleクレームの値が不正なトークンは拒否される」という3つのテストは、
いずれも最終的に同じ`Either JWTError AuthenticatedUser`の`Left`側に
帰着する。

### `UserError`がHTTPの語彙から独立していることの利点

`UserError`はHaskellの通常のデータ型（`data UserError = Forbidden |
InvalidEmail Text`）であり、Servantにもservant-serverにも依存しない。
この独立性には次のような利点がある。

- `User.Server`（Handlerの実装）は「権限がなければForbiddenを投げる」
  という**ビジネスルール**だけを書けばよく、「403という数字を返す」
  という**HTTPの詳細**を意識せずに済む。両者が1つの関数に混ざって
  いないため、どちらか一方だけをテストしたり変更したりしやすい。
- 将来、同じ`UserError`を（例えばgRPCやCLIツールなど）HTTP以外の
  インターフェースでも使う場合、`toServerError`に相当する変換関数を
  もう1つ用意するだけでよく、`UserError`自体やそれを投げる
  `User.Server`側のロジックには手を入れずに済む。

### `Forbidden`（403）と認証失敗（401）の違い

401 Unauthorizedは「あなたが誰なのか確認できなかった」ことを表す
（実際には認証情報がない、または不正であるという意味であり、
RFC 7235的には名前に反して「未認証」を指す）。403 Forbiddenは
「あなたが誰であるかは確認できたが、その操作を行う権限がない」ことを
表す。本教材のコードで言えば、401は`Auth.Server`の`authHandler`
（`AuthProtect`のルート解決の一部、`AuthenticatedUser`を構築できな
かった場合）から、403は`User.Server`の`createUserHandler`
（`AuthenticatedUser`は構築できたが、その`authRole`が`Admin`でな
かった場合）から、それぞれ別のコード・別のタイミングで発生する。

## 演習5-2の解説：mock-oauth2-serverでroleクレーム付きトークンを発行する

演習3-2で使った`claims`パラメータはJSONオブジェクト全体を受け取れる
ため、`tenant_id`と`role`を同時に含められる。

```sh
curl -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials \
  -d client_id=alice \
  -d client_secret=dummy \
  -d 'claims={"tenant_id":"acme","role":"admin"}'
```

実際のIdPでは「どのロールを持つか」はユーザーの認証結果（ログインした
本人が何者か）に基づいて発行されるべきであり、クライアントが任意の
`role`を指定できるこの挙動は、mock-oauth2-serverが提供する開発・テスト
専用の簡略化である（Iteration 3の演習3-6で`tenant_id`について述べたのと
同じ注意点が、`role`についても当てはまる）。

## 演習5-3の解説：JWT検証にrole抽出を追加する

```haskell
verify :: JWKSet -> Text -> ExceptT JWTError IO AuthenticatedUser
verify jwks token = do
  jwt <- decodeCompact (LBS.fromStrict (TE.encodeUtf8 token)) :: ExceptT JWTError IO SignedJWT
  claims <- verifyJWT (defaultJWTValidationSettings (const True)) jwks jwt :: ExceptT JWTError IO AuthClaims
  case subjectOf (authClaimsSet claims) of
    Just sub -> pure (AuthenticatedUser sub (TenantId (authClaimsTenantId claims)) (authClaimsRole claims))
    Nothing -> throwError (JWTClaimsSetDecodeError "subクレームがありません")
```

Iteration 3からの変更点は、`AuthenticatedUser`の3つ目の引数として
`authClaimsRole claims`を渡すようになったことだけである。`role`クレーム
の値の妥当性チェック（"admin"・"member"以外を拒否する）は
`AuthClaims`の`FromJSON`インスタンス（演習5-1で解説）がJWT全体の
デコード時点ですでに行っているため、`verify`関数自身が改めて`Role`の
値を検査するコードを書く必要はない。「クレームの値が正しい形をして
いることを型で保証し、それを使う側ではもう検査しなくてよい」という、
`FromJSON`インスタンスにバリデーションを閉じ込める設計の効果である。

## 演習5-4の解説：UserErrorのHTTPマッピングを実装する

```haskell
toServerError :: UserError -> ServerError
toServerError e@Forbidden        = jsonError err403 e
toServerError e@(InvalidEmail _) = jsonError err400 e

jsonError :: ServerError -> UserError -> ServerError
jsonError base e = base { errBody = encode e, errHeaders = jsonContentType : errHeaders base }

jsonContentType :: Header
jsonContentType = (hContentType, "application/json")
```

`err403`・`err400`はservant-serverが提供する定義済みの`ServerError`
値（それぞれ`errHTTPCode = 403`・`400`、標準的な`errReasonPhrase`を
持つ）である。`jsonError`はそれを土台に、`errBody`を`UserError`の
`ToJSON`インスタンスでエンコードしたJSONに差し替え、
`Content-Type: application/json`ヘッダを追加している。`e@Forbidden`の
ような`@`パターンは、パターンマッチで分解しつつ元の値全体
（`e :: UserError`）も同時に使いたい場合に使う（`encode e`のために
`UserError`の値そのものが必要なため）。

## 演習5-5の解説：権限チェック・バリデーションを実装する

```haskell
createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
createUserHandler authUser (CreateUserRequest reqName reqEmail)
  | authRole authUser /= Admin = throwUserError Forbidden
  | not (isValidEmail reqEmail) = throwUserError (InvalidEmail reqEmail)
  | otherwise =
      liftIO (createUser repo (authTenantId authUser) reqName reqEmail)
```

ガード（`|`）を上から順に評価し、最初に真になった節が使われる。権限
チェックを先に、バリデーションを後に置いているため、Memberロールの
ユーザーが不正なメールアドレスを送っても常に403が返る（400にはなら
ない）。これは意図的な順序である（演習5-7の問い3で扱う）：権限がない
リクエストに対しては、リクエスト内容の妥当性を検査する意味がそもそも
薄く、また「あなたのリクエストのどこが悪いか」という情報（400の
ボディに含まれるメールアドレスの検証結果）を権限のない相手に返す
必要はない。

```haskell
isValidEmail :: Text.Text -> Bool
isValidEmail email = case Text.splitOn "@" email of
  [local, domain] -> not (Text.null local) && not (Text.null domain)
  _ -> False
```

`Text.splitOn "@" email`は`email`を`"@"`で分割した`[Text]`を返す。
パターン`[local, domain]`は「ちょうど2要素（＝`@`がちょうど1つ）」の
場合にのみマッチし、それ以外（`@`がない、または2つ以上ある）は
`_ -> False`に落ちる。両側が空でないことも確認することで、
`"@example.com"`や`"alice@"`のような明らかに不正な入力を弾く。

## 演習5-6の解説：テストをすべてGREENにする

### 単体テストにおける権限・バリデーションの検証

```haskell
it "Memberロールのユーザーはcreateできない（403）" $ do
  repo <- newInMemoryUserRepository
  let create :<|> _list = server repo
  Left err <- runHandler (create memberUser (CreateUserRequest "Bob" "bob@example.com"))
  errHTTPCode err `shouldBe` 403
```

`runHandler`は`Handler a`を実行し`IO (Either ServerError a)`を返す。
`throwUserError`（内部で`Control.Monad.Except.throwError`を呼ぶ）に
到達すると`Handler`の計算全体が`Left`で終わるため、
`Left err <- runHandler ...`というパターンでその`ServerError`を
直接取り出し、`errHTTPCode`（HTTPステータスコードの整数値）を
アサーションできる。HTTP層を経由しないため、JSONボディのエンコード等
を気にせず、「何番のステータスコードになるべきか」という核心だけを
高速に検証できる。

### 結合テストにおける権限・バリデーションの検証

```haskell
it "Memberロールのトークンでは403 Forbiddenが返る" $
  request "POST" "/users" [("Content-Type", "application/json"), authHeader memberToken]
    [json|{name:"Bob",email:"bob@example.com"}|]
    `shouldRespondWith` 403
```

こちらはHTTP層を含めて、実際のJWT（`role: "member"`）を使ったリクエスト
が本当に403を返すことをend-to-endで確認している。単体テストが
「`createUserHandler`の中の分岐ロジック」を検証するのに対し、結合
テストは「JWTの`role`クレームからHTTPレスポンスまでの配線全体」を
検証しており、両者は異なるバグ（前者はビジネスロジックのバグ、後者は
JWT・ルーティング・シリアライズなど配線のバグ）を検出できる。

## 演習5-7の解説（発展）：実サーバーでの確認・設計の一般化

### 権限チェックとバリデーションの順序

演習5-5解説で述べたとおり、本教材の実装は権限チェックを先に行う。
これはOWASPが一般に推奨する考え方（認可は入力バリデーションより前に
行い、権限のない相手にはリクエスト内容の詳細な検証結果を返さない）
に沿っている。仮にバリデーションを先に行うと、Memberロールのユーザー
が「このメールアドレスは不正な形式だ」という情報（＝システムが自分の
入力をどこまで検査したか）を、そもそも実行を許されていない操作について
知ることができてしまう。些細な情報漏洩に見えるが、「エラーメッセージの
違いから、権限がなくてもシステムの内部動作を推測できてしまう」という
クラスの脆弱性の一種である。

### リソース所有者に基づく認可への拡張

本章の認可は「テナント内の全Adminが、そのテナントの全ユーザーを操作
できる」という粒度にとどまっている。「自分が作成したリソースしか
操作できない」という所有者ベースの認可を実現するには、例えば`User`型に
作成者（`createdBy :: Text`、`authSubject`と対応する値）を持たせ、
`UserRepository`に「指定した`sub`が所有するリソースだけを返す・
更新できる」ような操作を追加する必要がある。現状の`UserRepository`は
テナントIDだけでスコープしているが、同じ考え方（「アクセスを許可する
条件を関数の引数として要求し、条件を渡さずにデータへアクセスする経路を
作れなくする」）を、テナントIDだけでなく作成者IDにも適用すればよい。

### Iteration 6（ロギング）への接続

`AuthenticatedUser`（`authSubject`・`authTenantId`・`authRole`）と、
本章で導入した`UserError`（403・400として顕在化する）は、いずれも
「誰が・何をしようとして・どうなったか」という運用上重要な情報である。
Iteration 6でリクエストログを導入する際、これらの値をログの構造化
フィールドとして含めることで、「どのテナントのどのユーザーが、いつ、
何のエラーに遭遇したか」を後から追跡できるようになる。
