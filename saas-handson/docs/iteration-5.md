# Iteration 5：演習

## この章で作るもの

`POST /users`に、ロール（役割）に基づくアクセス制御と、リクエスト内容の
バリデーションを追加する。あわせて、失敗の理由を型で表現する
`UserError`という型を導入し、それをHTTPステータスコード・JSONボディへ
変換する仕組みを作る。

- **認可（ロールに基づくアクセス制御）**：JWTの`role`クレームから
  `Admin`・`Member`という役割を取り出し、`POST /users`は`Admin`にしか
  許可しない（`Member`は403 Forbidden）。認証（誰か）と認可（何をして
  よいか）は別の関心事であり、認証はIteration 2で導入した
  `AuthProtect "jwt"`（Servantのルーティング解決の一部としてハンドラ
  本体より先に走る）が担い、認可はハンドラ本体のドメインロジックとして
  書く。
- **ドメインエラー型の設計とHTTPへのマッピング**：`Forbidden`・
  `InvalidEmail`という2種類の失敗を`UserError`という1つの型で表現し、
  「`UserError`の値をどのHTTPステータスコード・JSONボディに変換する
  か」を1箇所（`User.Error.toServerError`）に集約する。

## 進め方

演習は5-1（型・仕組みを読み解く）→5-2（mock-oauth2-serverでroleクレーム
付きトークンを発行する）→5-3（JWT検証にrole抽出を追加する）→5-4
（UserErrorのHTTPマッピングを実装する）→5-5（権限チェック・バリデー
ションを実装する）→5-6（テスト全体の確認）→5-7（発展）という順で
積み上げる。詰まった場合は`saas-handson-solution/docs/iteration-5.md`
の対応する節を参照する。コマンドはリポジトリルート
（`cabal.project`のある場所）から実行する。

## 演習5-1：型・仕組みを読み解く

以下のファイルはすでに完成しており変更不要である。これらを読み、
下記の問いに自分の言葉で答えられるようにする（コードを書く必要はない）。

- `src/Auth/Types.hs`
- `src/User/Error.hs`のうち`UserError`型と`ToJSON UserError`インスタンス

```haskell
data Role = Admin | Member deriving (Show, Eq)

data AuthenticatedUser = AuthenticatedUser
  { authSubject  :: Text
  , authTenantId :: TenantId
  , authRole     :: Role
  } deriving (Show, Eq)
```

```haskell
data UserError
  = Forbidden
  | InvalidEmail Text
  deriving (Show, Eq)
```

1. `Role`の`FromJSON`インスタンスは、`"admin"`・`"member"`以外の文字列
   に対して`fail`を呼んでいる。この`fail`が呼ばれると、JWT検証全体
   （`Auth.Server`の`verify`、演習5-3で扱う）はどうなるか。tenant_idが
   欠落しているときと同じ結果になるか、考えてみる。
2. `UserError`は「HTTPステータスコードが何か」を一切知らない（`403`や
   `400`という数値はどこにも出てこない）。この型がHTTP・Servantの語彙
   から独立していることには、どういう利点があるか。
3. `Forbidden`（403）は認証済みであることを前提にした失敗、
   Iteration 2の「Authorizationヘッダがない・トークンが不正」（401）は
   認証そのものの失敗である。この2つの違いを自分の言葉で説明できるか
   （HTTPステータスコードの意味を調べて考える）。

## 演習5-2：mock-oauth2-serverでroleクレーム付きトークンを発行する

演習3-2で使った`claims`パラメータに`role`も含めることで、テナントIDと
ロールを組み合わせたトークンを発行できる。

```sh
curl -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials \
  -d client_id=alice \
  -d client_secret=dummy \
  -d 'claims={"tenant_id":"acme","role":"admin"}'
```

`role`の値を`"member"`に変えれば、`Member`ロールのトークンを発行できる
（演習5-7で疎通確認に使う）。

## 演習5-3：JWT検証にrole抽出を追加する

`src/Auth/Server.hs`の`verify`を実装する（Iteration 2・3から続く
TODOで、この演習でロール抽出も含めてまとめて実装する）。

```haskell
verify :: JWKSet -> Text -> ExceptT JWTError IO AuthenticatedUser
verify _jwks _token = error "TODO: Iteration 2/3/5で実装する"
```

演習3-3で実装した内容（`decodeCompact`・`verifyJWT`・`subjectOf`）に
加えて、今回は`AuthClaims`が`authClaimsRole :: Role`というフィールドも
持つようになっている。`AuthenticatedUser`を組み立てる際、
`authClaimsRole claims`をそのまま3つ目の引数として渡せばよい
（`FromJSON Role`インスタンスがすでに"admin"・"member"以外の値を
弾いてくれているため、ここで改めてバリデーションする必要はない）。

```sh
cabal test saas-handson:test:unit --test-options='--match "Auth"'
```

を実行し、`test/unit/Auth/AuthSpec.hs`の8件がすべてGREENになることを
確認する。

## 演習5-4：UserErrorのHTTPマッピングを実装する

`src/User/Error.hs`の`toServerError`を実装する。

```haskell
toServerError :: UserError -> ServerError
toServerError _ = error "TODO: Iteration 5で実装する"
```

- `Forbidden`は`Servant.err403`に、`InvalidEmail`は`Servant.err400`に
  対応させる。
- 同じファイルに定義済みの`jsonError`ヘルパー
  （`jsonError :: ServerError -> UserError -> ServerError`）を使うと、
  「`ServerError`のひな形に`UserError`をJSONエンコードしたボディと
  `Content-Type`ヘッダを追加する」という共通処理を1回書くだけで済む。
  例：`toServerError e@Forbidden = jsonError err403 e`

## 演習5-5：権限チェック・バリデーションを実装する

`src/User/Server.hs`の`createUserHandler`を実装する。

```haskell
createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
createUserHandler _authUser _req = error "TODO: Iteration 5で実装する"
```

- `authRole authUser`が`Admin`でなければ、`User.Error.throwUserError`に
  `User.Error.Forbidden`を渡して失敗させる。
- メールアドレスが`isValidEmail`（同じファイルに定義済み）を満たさなけ
  れば、`throwUserError (InvalidEmail reqEmail)`で失敗させる。
- どちらも満たせば、Iteration 4までと同じく
  `liftIO (createUser repo (authTenantId authUser) reqName reqEmail)`
  で`UserRepository`に委譲する。

権限チェックとバリデーションのどちらを先に行うべきか（権限がない
リクエストのメールアドレスが不正だった場合、403と400のどちらを返す
べきか）は演習5-7で扱う。

## 演習5-6：テストをすべてGREENにする

```sh
cabal test saas-handson:test:unit
```

を実行し、単体テストがすべてGREENになっていることを確認する
（`User.UserSpec`に追加された「Memberロールのユーザーはcreateできない
（403）」「メールアドレスの形式が不正なリクエストは拒否される（400）」
を含む）。

```sh
cabal test saas-handson:test:integration
```

を実行し、結合テストがすべてGREENになっていることを確認する
（devcontainerのdbサービスが起動していること、`db/schema.sql`が適用
済みであることが前提。詳しくは`docs/iteration-4.md`の「事前準備」を
参照）。新設した`POST /users（権限・バリデーション）`グループの3件が
HTTP層を含むend-to-endで確認できる。

## 演習5-7（発展）：実サーバーでの確認・設計の一般化

1. `cabal run saas-handson`でサーバーを起動し、演習5-2の要領で
   `role=admin`・`role=member`のトークンをそれぞれ取得する。
   `role=member`のトークンで`POST /users`すると403が、不正なメール
   アドレスで`POST /users`すると400が返ることを確認する。
2. `curl -v`（または`-i`）でレスポンスヘッダを確認し、
   `Content-Type: application/json`が付いていること、ボディが
   `{"error":"forbidden","message":"..."}`のような形になっていること
   を確認する。
3. 権限チェックとバリデーションの順序を入れ替えるとどうなるか（演習
   5-5の最後で触れた問い）。「Memberロールで不正なメールアドレスを
   送った」場合に403と400のどちらを返すべきか、セキュリティ上の観点
   （エラーメッセージから何が推測できてしまうか）も含めて考えてみる。
4. 本章では「テナント内のすべてのAdminがそのテナントの全ユーザーを
   作成・閲覧できる」という粒度の認可にとどめた。「自分が作成した
   ユーザーしか閲覧できない」のような、リソースの所有者に基づくより
   細かい認可を実現するには、`User`型・`UserRepository`にどのような
   変更が必要か設計してみる（実装は必須ではない）。
5. Iteration 6（ロギング・可観測性）では、`AuthenticatedUser`
   （`authSubject`・`authTenantId`・`authRole`）や、本章で発生した
   403・400といったエラーを、リクエストログにどう含めるとよいか
   考えてみる。

### 実装時に必要になるLANGUAGE拡張・依存パッケージ

| 用途 | 拡張／依存 |
|---|---|
| `UserError`のJSONエンコード（`errBody`への格納） | `aeson`パッケージ（既存の依存） |
| `ServerError`の`errHeaders`に`Content-Type`ヘッダを追加する | `http-types`パッケージ（`Network.HTTP.Types.Header`） |
| Roleクレームの文字列リテラルパターンマッチ（`Auth.Types`） | `{-# LANGUAGE OverloadedStrings #-}` |

`cabal build`・`cabal test`で「Could not load module」のようなエラーが
出た場合は、上記のいずれかが`.cabal`の`build-depends`に不足している
可能性が高い。
