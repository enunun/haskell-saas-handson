# Iteration 5：演習

## この章で作るもの

JWTの`role`クレーム（`admin`・`member`）に基づいて、`POST /users`を
`admin`だけに許可する。あわせて、HTTPの都合から独立したドメインエラー
型`UserError`（`Forbidden`・`InvalidEmail`）を導入し、`throwUserError`
で1箇所だけHTTPステータスコード・JSONボディへ変換する。認証（誰か、
401、Iteration 2）と認可（何をしてよいか、403、本Iteration）を明確に
分離する。

## 進め方

演習は5-1から順に取り組む。詰まった場合は`../solution/docs/iteration-5.md`
の対応する節を読む。コマンドはリポジトリルート（`cabal.project`のある
場所）から実行する。

## 演習5-1：AuthenticatedUserにRoleを追加する

Iteration 3でテナントIDを追加したのと同じ要領で、今度はロールを追加
する。

1. `src/Auth/Types.hs`に、ロールを表す型を追加する。

   ```haskell
   -- src/Auth/Types.hs
   data Role = Admin | Member deriving (Show, Eq)

   instance FromJSON Role where
     parseJSON = withText "Role" $ \t -> case t of
       "admin"  -> pure Admin
       "member" -> pure Member
       other    -> fail ("unknown role: " ++ show other)
   ```

2. `AuthenticatedUser`に`authRole :: Role`フィールドを追加する。

## 演習5-2：JWTからroleクレームを取り出す

`src/Auth/Server.hs`の`AuthClaims`に、`tenant_id`のときと同じ要領で
`role`クレームを追加する。

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

`verify`が`AuthenticatedUser`を組み立てる部分に`authClaimsRole claims`を
渡すように変更する。`role`クレームの値が`"admin"`・`"member"`以外
であれば、`Auth.Types`の`FromJSON Role`インスタンスがパースに失敗し、
`AuthClaims`全体のパースが失敗する（そのトークンは401になる）。

## 演習5-3：既存のテストを直す

演習5-1〜5-2の変更により、既存の単体テストはコンパイルエラーになり
（`AuthenticatedUser`の引数が1つ増えたため）、既存の結合テストは
`role`クレームがないトークンで401になる（Iteration 3の演習3-3と同じ
パターンである）。

1. 単体テストの`AuthenticatedUser`の値に`Admin`を追加する。
2. 結合テストのトークン組み立てに、`addClaim "role" (String "admin")`
   を追加する。

```sh
cabal test saas-handson-iteration5:test:unit saas-handson-iteration5:test:integration
```

を実行し、既存のテストがすべてGREENに戻ることを確認する（振る舞いは
まだ変えていないので、まだ権限による制御は実現していない）。

## 演習5-4：ドメインエラー型を完成させる

`src/User/Error.hs`の`UserError`型（`Forbidden`・`InvalidEmail Text`）は
すでに定義されているが、`throwUserError`はまだ`error "TODO: ..."`の
ままである。`Forbidden`はステータスコード403、`InvalidEmail`は
ステータスコード400に対応させ、それぞれJSONのエラーボディ
（例：`{"error":"forbidden"}`、`InvalidEmail`は不正だったメール
アドレスも含める）と`Content-Type: application/json`ヘッダを持つように
実装する（`src/User/Error.hs`のヒントを参照）。

以降の演習5-5〜5-7では、権限チェック・メールアドレス検証・結合テストを
1つずつ順番にテストと実装に落とす。まとめて4つのテストケースを書いて
から`createUserHandler`をまとめて書き換える、という進め方はしない。

## 演習5-5：権限チェックを検証する（Red→Green）

1. 「`Role`が`Member`の`AuthenticatedUser`で作成ハンドラを呼ぶと失敗
   する（`Left`になる）」ことを検証する単体テストを1つ追加する。
2. `cabal test saas-handson-iteration5:test:unit`を実行し、REDになる
   ことを確認する。
3. `src/User/Server.hs`の`createUserHandler`に、`authRole authUser`が
   `Admin`でなければ`User.Error.throwUserError Forbidden`を投げる
   チェックを追加し、GREENにする。

## 演習5-6：メールアドレス検証を検証する（Red→Green）

1. 「メールアドレスの形式が不正な`CreateUserRequest`で`Admin`の
   `AuthenticatedUser`から作成ハンドラを呼ぶと失敗する」ことを検証する
   単体テストを追加する。REDになることを確認する。
2. `createUserHandler`に、メールアドレスの形式が不正であれば
   `User.Error.throwUserError (InvalidEmail (crEmail req))`を投げる
   チェックを追加する（形式チェック用のヘルパー関数
   `isValidEmail :: Text -> Bool`も自分で書く。「`@`がちょうど1つ、
   両側が空でない」程度の簡易チェックでよい）。どちらのチェックも
   満たせば、Iteration 4までと同じく`User.Repository`に委譲する。
3. GREENになることを確認する。

## 演習5-7：結合テストで同じ振る舞いを確認する

以下を検証する結合テストを追加する。

- `role`が`member`のトークンで`POST /users`すると403が返る。
- 不正な形式のメールアドレスで`POST /users`すると400が返る。

```sh
cabal test saas-handson-iteration5:test:unit saas-handson-iteration5:test:integration
```

を実行し、演習5-5〜5-7で追加したテストがすべてGREENになることを
確認する。

## 演習5-8：単体テスト・結合テストへの影響を考える

1. 認証（401）はServantの`AuthProtect`・`Auth.Server`が、認可（403）は
   `User.Server`のハンドラ本体が、それぞれ別の場所で判定している。
   この2つを同じ場所で判定しなかった理由を考える。
2. `UserError`という型を経由せず、`User.Server`から直接
   `throwError err403`のように書いた場合と比べて、`UserError`を
   間に挟むことにどんな利点があるか。

## 演習5-9（発展）：疎通確認

```sh
TOKEN_MEMBER=$(curl -s -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials -d client_id=carol -d client_secret=dummy \
  -d 'claims={"tenant_id":"acme","role":"member"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl -i -X POST http://localhost:8080/users -H "Authorization: Bearer $TOKEN_MEMBER" \
  -H 'Content-Type: application/json' -d '{"name":"Alice","email":"alice@example.com"}'
```

memberのトークンでは403が返り、レスポンスボディに`{"error":"forbidden"}`
が含まれることを確認する。
