# Iteration 3：演習

## この章で作るもの

JWTの`tenant_id`クレームに基づいて、ユーザーデータをテナント（契約
企業）ごとに完全に分離する。`AuthenticatedUser`にテナントIDを追加し、
`POST /users`・`GET /users`・`GET /users/{id}`のin-memoryストアを
テナントIDでスコープする。あるテナントのユーザーが他テナントのデータへ
到達する経路が存在しないようにする。

## 進め方

演習は3-1から順に取り組む。詰まった場合は`../solution/docs/iteration-3.md`
の対応する節を読む。コマンドはリポジトリルート（`cabal.project`のある
場所）から実行する。

## 演習3-1：AuthenticatedUserにテナントIDを追加する

1. `src/Auth/Types.hs`に、テナントを識別する型を追加する。

   ```haskell
   -- src/Auth/Types.hs
   newtype TenantId = TenantId { unTenantId :: Text } deriving (Show, Eq, Ord)
   ```

   （`Ord`を導出するのは、後で`Map TenantId (...)`のキーとして使うため
   である。）

2. `AuthenticatedUser`に`authTenantId :: TenantId`フィールドを追加する。

## 演習3-2：JWTからtenant_idクレームを取り出す

`tenant_id`はJWTの標準クレームではないため、`sub`のように`ClaimsSet`
から直接取り出すことができない。`src/Auth/Server.hs`の`verify`を、
`tenant_id`クレームも取り出せるように変更する。

joseは非標準クレームを扱う場合、標準の`ClaimsSet`をラップした独自の型に
`HasClaimsSet`・`FromJSON`インスタンスを与えることを推奨している。

```haskell
-- src/Auth/Server.hs
data AuthClaims = AuthClaims
  { authClaimsSet      :: ClaimsSet
  , authClaimsTenantId :: Text
  }

instance HasClaimsSet AuthClaims where
  claimsSet f s = fmap (\a' -> s { authClaimsSet = a' }) (f (authClaimsSet s))

instance FromJSON AuthClaims where
  parseJSON = withObject "AuthClaims" $ \o ->
    AuthClaims <$> parseJSON (Object o) <*> o .: "tenant_id"
```

この`AuthClaims`を、`verifyJWT`が検証対象とする型として使う
（`verify`の型シグネチャの`ExceptT JWTError IO ClaimsSet`を
`ExceptT JWTError IO AuthClaims`に変える）。`subjectOf`は
`authClaimsSet claims`に対して呼び出せばよい。`tenant_id`クレームが
なければ、`AuthClaims`の`FromJSON`インスタンスがパースに失敗し、
`verifyJWT`全体が失敗する（`tenant_id`がないトークンは401になる）。

## 演習3-3：既存のテストを直す（Red）

演習3-1〜3-2の変更により、既存の`test/unit/User/UserSpec.hs`は
コンパイルエラーになる（`AuthenticatedUser`が引数を2つ取るようになった
ため）。`test/integration/User/UserSpec.hs`は、既存のトークンに
`tenant_id`クレームがないため401になり、テストが失敗する
（ランタイムのRed）。

1. `test/unit/User/UserSpec.hs`の`testUser`に`TenantId`を追加する
   （例：`AuthenticatedUser "alice" (TenantId "acme")`）。
2. `test/integration/User/UserSpec.hs`のトークン組み立て
   （`signToken`相当の関数）に、`Crypto.JWT`の`addClaim`で
   `tenant_id`クレームを追加する。

```sh
cabal test saas-handson-iteration3:test:unit saas-handson-iteration3:test:integration
```

を実行し、コンパイルが通り、既存のテストがすべてGREENに戻ることを
確認する（振る舞いはまだ変えていないので、ここではまだテナント分離は
実現していない）。

以降の演習3-4〜3-7では、テナント分離の振る舞いを1つずつテストに落とし、
そのテストだけを通す最小限の変更を`User.Store`・`User.Server`に加える、
というサイクルを繰り返す。4つのテストケースをまとめて書いてから
`User.Store`をまとめて書き換える、という進め方はしない。

## 演習3-4：採番がテナントごとに独立していることを検証する（Red→Green）

1. 「異なる`TenantId`を持つ`AuthenticatedUser`でそれぞれユーザーを
   作成すると、両方ともid=1から採番される」ことを検証する単体テストを
   1つ追加する。
2. `cabal test saas-handson-iteration3:test:unit`を実行し、REDになる
   ことを確認する（`User.Store`がまだテナントを区別していないため）。
3. `src/User/Store.hs`を、テナントごとにデータを分離するように変更
   する。

   ```haskell
   -- src/User/Store.hs
   newtype Store = Store (IORef (Map TenantId (Int, Map Int User)))
   ```

   `createUser`・`listUsers`・`getUser`はいずれも`TenantId`を引数に
   取り、対応するテナントの`(Int, Map Int User)`だけを読み書きする
   ように変更する（存在しないテナントは`Map.findWithDefault (1,
   Map.empty)`のように扱えばよい）。`src/User/Server.hs`の3つの
   ハンドラも、`authTenantId authUser`を`User.Store`の各関数に渡す
   ように変更する。
4. GREENになることを確認する。

## 演習3-5：一覧が自テナントに閉じていることを検証する（Red→Green）

1. 「`GET /users`相当のハンドラは、自テナントのユーザーだけを返す」
   ことを検証する単体テストを追加する。
2. 演習3-4で`User.Store.listUsers`をすでにテナントでスコープして
   いれば、追加のコード変更なしにGREENになるはずである。RED・GREEN
   いずれの場合も、その理由を説明できるようにする。

## 演習3-6：単一取得がテナント境界を越えないことを検証する（Red→Green）

1. 「あるテナントが作成したユーザーのidを、別のテナントの
   `AuthenticatedUser`で取得しようとすると404になる」ことを検証する
   単体テストを追加する。
2. 演習3-4の変更で対応できていなければ、`getUser`を修正してGREENに
   する。

## 演習3-7：結合テストで同じ振る舞いを確認する

「テナントAが作成したユーザーのidを、テナントBのトークンで
`GET /users/{id}`すると404になる」ことを検証する結合テストを追加する。

```sh
cabal test saas-handson-iteration3:test:unit saas-handson-iteration3:test:integration
```

を実行し、演習3-4〜3-7で追加したテスト・既存のテストがすべてGREENに
なることを確認する。

## 演習3-8：単体テストと結合テストへの影響を考える

1. 演習3-3で、単体テストと結合テストは異なる理由で失敗した
   （コンパイルエラー vs. ランタイムの401）。なぜ違いが生まれたかを、
   それぞれのテストが認証の経路をどこまで通るかから説明する。
2. `Health`機能のテストは、この演習を通して一切変更していない。
   Iteration 2の演習でも同じ問いを扱ったが、今回も同じ理由で説明が
   つくか確認する。

## 演習3-9（発展）：疎通確認

`cabal run saas-handson-iteration3`でサーバーを起動し、異なる
`tenant_id`を持つ2つのトークンを取得して、テナントが分離されている
ことを実際に確認する。

```sh
TOKEN_ACME=$(curl -s -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials -d client_id=alice -d client_secret=dummy \
  -d 'claims={"tenant_id":"acme"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

TOKEN_GLOBEX=$(curl -s -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials -d client_id=bob -d client_secret=dummy \
  -d 'claims={"tenant_id":"globex"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl -X POST http://localhost:8080/users -H "Authorization: Bearer $TOKEN_ACME" \
  -H 'Content-Type: application/json' -d '{"name":"Alice","email":"alice@example.com"}'

curl http://localhost:8080/users -H "Authorization: Bearer $TOKEN_GLOBEX"
```

テナントglobexのトークンで`GET /users`しても、テナントacmeで作成した
Aliceは返らないことを確認する。
