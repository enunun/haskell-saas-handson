# Iteration 3：演習

## この章で作るもの

`POST /users`・`GET /users`にテナント分離を導入する。toB SaaSでは複数の
契約企業（テナント）が同じアプリケーションを使うため、あるテナントの
ユーザーが別テナントのデータを閲覧・操作できてはならない。本教材では
テナントIDをJWTの`tenant_id`クレームとして受け取り、Iteration 2で導入
した`AuthenticatedUser`型に追加する。ハンドラはこの`AuthenticatedUser`
からテナントIDを取り出し、in-memoryストアをテナントIDでスコープする。

「Servantのコンテキストや型を使ってテナント境界を表現する」というのが
本章のテーマである。認証（Iteration 2）で確立した「認証済みリクエストに
は必ず`AuthenticatedUser`が渡ってくる」という骨組みを、「その
`AuthenticatedUser`は必ずテナントIDを持つ」という形に拡張することで、
ハンドラがテナントIDを受け取り忘れる（＝チェックを書き忘れる）余地を
型レベルでなくす。

## 進め方

演習は3-1（型・仕組みを読み解く）→3-2（mock-oauth2-serverでtenant_id
クレーム付きトークンを発行する）→3-3（JWT検証にtenant_id抽出を追加する）
→3-4（ストアのテナント分離を実装する）→3-5（テスト全体の確認）→3-6
（発展）という順で積み上げる。詰まった場合は
`saas-handson-solution/docs/iteration-3.md`の対応する節を参照する。
コマンドはリポジトリルート（`cabal.project`のある場所）から実行する。

## 演習3-1：テナント分離の仕組みを読み解く

以下のファイルはすでに完成しており変更不要である。これらを読み、
下記の問いに自分の言葉で答えられるようにする（コードを書く必要はない）。

- `src/Auth/Types.hs`
- `src/Auth/Server.hs`の`TenantClaims`型とその`HasClaimsSet`・
  `FromJSON`インスタンス

```haskell
newtype TenantId = TenantId { unTenantId :: Text } deriving (Show, Eq, Ord)

data AuthenticatedUser = AuthenticatedUser
  { authSubject  :: Text
  , authTenantId :: TenantId
  } deriving (Show, Eq)
```

```haskell
data TenantClaims = TenantClaims
  { tenantClaimsSet      :: ClaimsSet
  , tenantClaimsTenantId :: Text
  }

instance HasClaimsSet TenantClaims where
  claimsSet f s = fmap (\a' -> s { tenantClaimsSet = a' }) (f (tenantClaimsSet s))

instance FromJSON TenantClaims where
  parseJSON = withObject "TenantClaims" $ \o ->
    TenantClaims <$> parseJSON (Object o) <*> o .: "tenant_id"
```

1. `TenantId`は`Ord`を導出している。`Auth.Types`単体を見ただけでは
   何のために`Ord`が必要か分からない。`src/User/Server.hs`の`Store`型
   （演習3-4で扱う）と結び付けて、理由を説明してみる。
2. `TenantClaims`はなぜ`ClaimsSet`を直接使わず、`ClaimsSet`をラップした
   独自の型を定義しているのか。`Crypto.JWT`の`ClaimsSet`型が知っている
   フィールド（`sub`・`exp`・`iss`など、RFC 7519で定義されたもの）と
   `tenant_id`の違いに注目して考える。
3. `TenantClaims`の`FromJSON`インスタンスは`parseJSON (Object o)`という
   式で`ClaimsSet`部分をパースしている。この`parseJSON`はどの型の
   `FromJSON`インスタンスが呼ばれているか。
4. Iteration 2の時点の`verify`は`Crypto.JWT.verifyClaims`
   （`ClaimsSet`専用）を使っていたが、Iteration 3では`TenantClaims`を
   使うために別の関数に変える必要がある。`Crypto.JWT`のドキュメントを
   調べ、`ClaimsSet`以外の任意のペイロード型を検証できる関数を探す
   （演習3-3で実際に使う）。

## 演習3-2：mock-oauth2-serverでtenant_idクレーム付きトークンを発行する

mock-oauth2-serverは、トークンリクエストに`claims`という追加パラメータ
（JSON文字列）を渡すことで、発行されるJWTに任意の非標準クレームを
含められる。このコンテナ（devcontainer）の中から確認する。

```sh
curl -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials \
  -d client_id=alice \
  -d client_secret=dummy \
  -d 'claims={"tenant_id":"acme"}'
```

レスポンスの`access_token`をデコードし、`sub`（＝`alice`）に加えて
`tenant_id`（＝`acme`）が含まれていることを確認する。この
`tenant_id`パラメータの値を変えれば、異なるテナントに属するトークンを
好きなだけ発行できる（演習3-6で疎通確認に使う）。

## 演習3-3：JWT検証にtenant_id抽出を追加する

`src/Auth/Server.hs`の`verify`を実装する（Iteration 2の続きで、まだ
未着手の場合はこの演習でまとめて実装する）。

```haskell
verify :: JWKSet -> Text -> ExceptT JWTError IO AuthenticatedUser
verify _jwks _token = error "TODO: Iteration 2/3で実装する"
```

- `decodeCompact`でコンパクト表現をデコードする点はIteration 2と同じ
  だが、型注釈を`SignedJWT`にする。
- 検証には`Crypto.JWT.verifyClaims`ではなく`Crypto.JWT.verifyJWT`を
  使う（演習3-1の問い4の答え）。`verifyJWT`にはペイロードの型として
  `TenantClaims`を指定する（型注釈で明示する）。
- `sub`クレームの取り出しは`(verifyJWTの戻り値).tenantClaimsSet`に対して
  Iteration 2と同じ方法（`claimSub`・`(^?)`・`_Just`・`string`）で行う。
- `tenant_id`は`TenantClaims`の`tenantClaimsTenantId`フィールドから
  そのまま取り出せる（`TenantClaims`の`FromJSON`インスタンスが
  デコード時点で`tenant_id`フィールドのパースを保証しているため、
  失敗しうるのはJWT全体のデコード・検証の段階だけである）。

```sh
cabal test saas-handson --test-options='--match "Auth"'
```

を実行し、`test/unit/Auth/AuthSpec.hs`の5件（有効なトークン・期限切れ・
未登録の鍵・壊れたトークン文字列・tenant_idクレームなし）がすべて
GREENになることを確認する。

## 演習3-4：ストアのテナント分離を実装する

`src/User/Server.hs`の`createUserHandler`・`listUsersHandler`を実装する
（Iteration 1から未着手の場合はこの演習でまとめて実装する）。

```haskell
type Store = IORef (Map TenantId (Int, [User]))

newStore :: IO Store
newStore = newIORef Map.empty
```

`Store`はIteration 1の`IORef (Int, [User])`から、テナントIDをキーとする
`Map`に変わっている（`newStore`はすでに実装済み）。

- `authUser :: AuthenticatedUser`から`authTenantId authUser`で
  テナントIDを取り出す。
- `createUserHandler`：`Data.Map.Strict.findWithDefault (1, [])`で
  該当テナントの現在の状態（未登録なら`(1, [])`）を取り出し、
  Iteration 1と同じ要領で新しいユーザーを作る。その後
  `Data.Map.Strict.insert`で該当テナントのエントリだけを更新する。
  Iteration 1と同様、採番とMapの更新は`atomicModifyIORef'`で単一の
  原子的操作として行う。
- `listUsersHandler`：`Data.Map.Strict.lookup`で該当テナントのエントリ
  を探し、見つからなければ空リストを返す。

## 演習3-5：テストをすべてGREENにする

```sh
cabal test saas-handson
```

を実行し、以下がすべてGREENになっていることを確認する。

- `test/unit/Auth/AuthSpec.hs`の5件。
- `test/unit/User/UserSpec.hs`の5件（うち2件がIteration 3で追加した
  テナント分離のテスト：「別テナントのユーザーは互いに見えない」
  「テナントごとにid採番が独立している」）。
- `test/integration/User/UserSpec.hs`の8件（うち1件がテナント分離の
  結合テスト：「別テナントのトークンでは他テナントが作成したユーザーが
  見えない」）。

特に単体テストの「テナントごとにid採番が独立している」がGREENになる
ことは、`Store`をテナントIDでスコープしたことで、あるテナントの
ユーザー数が別テナントの採番に影響しなくなったことを意味する
（Iteration 1の時点では全テナントが1つのカウンタを共有していた、という
のは正確ではなく、Iteration 1・2の時点ではそもそも「テナント」という
概念自体が存在しなかった）。

## 演習3-6（発展）：実サーバーでの疎通確認・設計の一般化

1. `cabal run saas-handson`でサーバーを起動し、演習3-2の要領で
   `tenant_id`の異なる2つのトークンを取得する。片方のトークンで
   `POST /users`しユーザーを作成したあと、もう片方のトークンで
   `GET /users`し、空配列が返る（＝相手のテナントのユーザーが見えない）
   ことを確認する。
2. 本教材では`tenant_id`クレームの値をそのままテナントの識別子として
   信頼している。実務では、JWTを発行する認証サーバー側で
   「そのユーザーが本当にそのテナントに所属しているか」を検証してから
   `tenant_id`クレームを発行する必要がある（さもないと、任意の
   `tenant_id`を主張するトークンを取得できてしまえば他テナントのデータ
   に到達できてしまう）。本教材のmock-oauth2-serverは`claims`パラメータ
   でクライアントが任意の`tenant_id`を指定できてしまうが、これは
   モックだからこそ許されている簡略化である。実際の認証サーバー
   （Keycloak等）ではテナント所属をどう検証・発行するか、調べて考えて
   みる。
3. Iteration 4（永続化層の導入）でin-memoryストアをDBに置き換える際、
   テナント分離をどう維持するか設計してみる（例：テーブルに
   `tenant_id`列を持たせて全クエリでWHERE句に含める、テナントごとに
   スキーマ・データベースを分ける、など）。

### 実装時に必要になるLANGUAGE拡張・依存パッケージ

| 用途 | 拡張／依存 |
|---|---|
| `TenantId`を`Map`のキーとして使う（`Ord`導出） | 追加の拡張は不要（`deriving (Ord)`は標準） |
| `Map TenantId (Int, [User])` | `containers`パッケージ（`Data.Map.Strict`） |
| `TenantClaims`の`FromJSON`インスタンス内での`parseJSON (Object o)` | `aeson`パッケージ（既存の依存） |

`cabal build`・`cabal test`で「Could not load module」のようなエラーが
出た場合は、上記のいずれかが`.cabal`の`build-depends`に不足している
可能性が高い。
