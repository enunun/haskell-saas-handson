# Iteration 5：解説

このドキュメントは`../../exercise/docs/iteration-5.md`の演習問題に対応する
解答解説である。見出しの番号（5-1〜5-9）は演習側と対応している。

## 演習5-1の解説：AuthenticatedUserにRoleを追加する

Iteration 3で`TenantId`を追加したときと全く同じ形で`Role`を追加する。

```haskell
-- src/Auth/Types.hs
data Role = Admin | Member deriving (Show, Eq)

instance FromJSON Role where
  parseJSON = withText "Role" $ \t -> case t of
    "admin"  -> pure Admin
    "member" -> pure Member
    other    -> fail ("unknown role: " ++ show other)

data AuthenticatedUser = AuthenticatedUser
  { authSubject  :: Text
  , authTenantId :: TenantId
  , authRole     :: Role
  } deriving (Show, Eq)
```

`FromJSON Role`インスタンスが`"admin"`・`"member"`以外の値を拒否する
ため、`role`クレームの妥当性検証はここで一括して行われる
（`User.Server`側では、値が正しい`Role`型であることはすでに保証されて
いる）。この時点では`Auth.Server`はまだ`role`クレームを取り出していない
ので、コンパイルは通らない。

## 演習5-2の解説：JWTからroleクレームを取り出す

Iteration 3で`tenant_id`を`AuthClaims`に追加したときと同じ要領で、
`role`クレームも追加する。

```haskell
-- src/Auth/Server.hs
data AuthClaims = AuthClaims
  { authClaimsSet      :: ClaimsSet
  , authClaimsTenantId :: Text
  , authClaimsRole     :: Role
  }

instance FromJSON AuthClaims where
  parseJSON = withObject "AuthClaims" $ \o ->
    AuthClaims <$> parseJSON (Object o) <*> o .: "tenant_id" <*> o .: "role"
```

`verify`が`AuthenticatedUser`を組み立てる部分にも`authClaimsRole
claims`を渡すように変更する。

## 演習5-3の解説：既存のテストを直す

既存のテストがコンパイルエラー・401になる理由はIteration 3の演習3-3と
同じである。単体テストは値の組み立て方を直せばよく、結合テストは
トークンに`role`クレームを追加すればよい。

## 演習5-4の解説：ドメインエラー型を完成させる

```haskell
-- src/User/Error.hs
throwUserError :: UserError -> Handler a
throwUserError err = throwError (base { errBody = encode (errorBody err), errHeaders = jsonContentType : errHeaders base })
  where
    base = case err of
      Forbidden      -> err403
      InvalidEmail _ -> err400
    jsonContentType = ("Content-Type", "application/json")
    errorBody Forbidden = object ["error" .= ("forbidden" :: String)]
    errorBody (InvalidEmail email) =
      object ["error" .= ("invalid_email" :: String), "email" .= email]
```

`err403`・`err400`はservantが用意する既定の`ServerError`値（ステータス
コードだけが設定済み）である。レコード更新構文`base { errBody = ...,
errHeaders = ... }`で、ボディ・ヘッダだけを差し替える。`Data.Aeson`の
`object`は`[(Text, Value)]`から`Value`を組み立て、`encode`はその
`Value`をJSONの`ByteString`にシリアライズする。`InvalidEmail`は
不正だった値自体（`Text`）を持つため、エラーボディにも含められる。

## 演習5-5の解説：権限チェックを検証する

```haskell
-- src/User/Server.hs
createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
createUserHandler authUser req
  | authRole authUser /= Admin = throwUserError Forbidden
  | ...
```

パターンガード（`|`で始まる条件式を上から順に試す書き方）を使うと、
「権限チェック→入力検証→本来の処理」という順序を、`if`のネストなしに
フラットに表現できる。この時点では権限チェックの節だけを追加し、
`otherwise`節（これまで通り`User.Repository`に委譲する）はまだ変えない。

## 演習5-6の解説：メールアドレス検証を検証する

```haskell
-- src/User/Server.hs
createUserHandler authUser req
  | authRole authUser /= Admin = throwUserError Forbidden
  | not (isValidEmail (crEmail req)) = throwUserError (InvalidEmail (crEmail req))
  | otherwise = liftIO (createUser repo (authTenantId authUser) (crName req) (crEmail req))

isValidEmail :: Text.Text -> Bool
isValidEmail email = case Text.splitOn "@" email of
  [local, domain] -> not (Text.null local) && not (Text.null domain)
  _ -> False
```

演習5-5で追加した権限チェックの節はそのままに、2つ目のガード節として
メールアドレス検証を追加する。`isValidEmail`は`Text.splitOn "@"`で`@`の
前後に分割し、ちょうど2つに分かれ、かつどちらも空でないことだけを
確認する簡易チェックである。

## 演習5-7の解説：結合テストで同じ振る舞いを確認する

単体テスト（演習5-5〜5-6）ですでに`createUserHandler`の実装を終えて
いるため、結合テストはHTTP経由でも同じステータスコード（403・400）に
なっていることを確認するだけになる。

## 演習5-8の解説：単体テスト・結合テストへの影響を考える

問い1の答え：認証（「誰か」を確定させる、失敗すれば401）はServantの
`AuthProtect`という型レベルの仕組みによって、ハンドラ本体が呼ばれる
**前**に一律に行われる。認可（「その誰かが、この操作をしてよいか」、
失敗すれば403）は、操作（エンドポイント）ごとに異なるルールを持つ
ドメインロジックであり、ハンドラ本体でなければ判定できない
（`POST /users`は`admin`のみ、`GET /users`は誰でも、というように
エンドポイントごとにルールが違う）。この2つを同じ場所で判定すると、
「認証が通ったリクエストの中の、一部だけ権限が足りない」という状況を
表現できなくなる。

問い2の答え：`UserError`を経由せず`User.Server`から直接
`throwError err403`と書くと、HTTPのステータスコード・ボディの形式を
決める責務が、ドメインロジック（権限チェック）のあちこちに散らばって
しまう。`UserError`という中間の型を挟むことで、「HTTPにどう変換するか」
という関心事を`User.Error`の`throwUserError`1箇所にまとめられる
（例えば将来レスポンスのエラーボディの形式を変えたくなっても、
`User.Server`側は一切変更する必要がない）。

## 使用ライブラリ

Iteration 4からの追加はない。`aeson`の`encode`・`object`・`.=`を
エラーレスポンスのボディ組み立てに応用した点が新しい。
