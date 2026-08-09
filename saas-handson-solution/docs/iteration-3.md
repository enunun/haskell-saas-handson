# Iteration 3：解説

このドキュメントは`saas-handson/docs/iteration-3.md`の演習問題に対応する
解答解説である。見出しの番号（3-1〜3-6）は演習側と対応している。

## 設計判断：テナントIDをJWTクレームとして受け取る

ROADMAPのIteration 3は「テナントIDに基づくデータ分離」を目的とする。
Iteration 2で「外部認証サーバーが発行するJWTを検証し、`sub`クレームから
`AuthenticatedUser`を作る」という仕組みを確立したため、Iteration 3では
その延長として、JWTに含まれる`tenant_id`という非標準クレームから
テナントIDを取り出す設計にした。認証サーバー（本教材では
mock-oauth2-server）が「このユーザーはどのテナントに属するか」を検証
した上でクレームとして発行し、アプリケーションはそれを信頼するだけ、
という責務分担である。この設計は現実のtoB SaaSでもよく採られる
（IdP側でテナント所属を管理し、JWTのカスタムクレームとして払い出す）。

テナント分離の実装は2箇所に閉じている。

1. `Auth.Server`：JWTから`tenant_id`クレームを取り出し、
   `AuthenticatedUser`に含める（＝「誰が」に「どのテナントとして」を
   加える）。
2. `User.Server`：in-memoryストアをテナントIDでスコープし、
   `AuthenticatedUser`のテナントID以外のデータには一切アクセスしない。

`User.Api`・root`Server.hs`・`Main.hs`は変更していない。Iteration 2で
確立した「`AuthProtect "jwt"`を通過すると`AuthenticatedUser`が手に入る」
という骨組みに、`AuthenticatedUser`が運ぶ情報を1つ追加しただけで済んで
おり、認証の骨組み自体を作り変える必要がなかった。これはIteration 2の
設計（Servantの型システムで「誰がアクセスしているか」を表現する）が
Iteration 3の要件を見越していたことの証左であり、`AuthenticatedUser`と
いう1つの型に認証由来の情報を集約する設計の効果である。

## 演習3-1の解説：テナント分離の仕組みを読み解く

### `TenantId`の`Ord`導出

```haskell
newtype TenantId = TenantId { unTenantId :: Text } deriving (Show, Eq, Ord)
```

`User.Server`の`Store`は`IORef (Map TenantId (Int, [User]))`という型に
なっている（演習3-4）。`Data.Map.Strict`の`Map k v`はキー`k`の比較に
基づく平衡二分探索木であり、キー型`k`に`Ord`インスタンスが要求される。
`TenantId`をこのMapのキーとして使うために`Ord`の導出が必要だった。

### `TenantClaims`：`ClaimsSet`をラップしたサブタイプ

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

`Crypto.JWT`の`ClaimsSet`型は、RFC 7519が定義する登録済みクレーム
（`iss`・`sub`・`aud`・`exp`・`nbf`・`iat`・`jti`）専用のフィールドしか
持たない。`tenant_id`はこの仕様の外側にある、本教材が独自に定義した
クレームである。`jose`ライブラリのhaddockドキュメント（`Crypto.JWT`の
`$subtypes`節）は、こうした非標準クレームを扱う場合、
`ClaimsSet`に非標準クレームを後付けする`unregisteredClaims`
レンズ（非推奨）を直接使うのではなく、`ClaimsSet`をラップした独自の
データ型を定義し、`HasClaimsSet`・`FromJSON`（署名する場合は`ToJSON`も）
インスタンスを与えることを推奨している。`TenantClaims`はこの推奨パターン
そのものである。

`FromJSON`インスタンスの`parseJSON (Object o)`は、`ClaimsSet`の
`FromJSON`インスタンス（`instance FromJSON ClaimsSet where parseJSON = ...`）
を同じJSONオブジェクト`o`に対して呼び出している。つまりJWTのペイロード
JSON全体を、標準クレーム部分は`ClaimsSet`のパーサに、`tenant_id`部分は
`o .: "tenant_id"`にそれぞれ委譲し、両方の結果を`TenantClaims`
コンストラクタで組み合わせている。1つのJSONオブジェクトを複数の
`FromJSON`インスタンスで「多重にパースする」という、Haskellの型クラス
らしいコードの再利用の仕方である。

### `verifyClaims`から`verifyJWT`へ

`Crypto.JWT`の`verifyClaims`は`ClaimsSet`専用（`verifyJWT`の
ペイロード型を`ClaimsSet`に固定した特殊化）である。`TenantClaims`は
`ClaimsSet`そのものではない別の型なので、汎用版の`verifyJWT`
（`HasClaimsSet payload, FromJSON payload`という制約を持つ任意の
ペイロード型を受け取れる）を使う必要がある。

## 演習3-2の解説：mock-oauth2-serverでtenant_idクレーム付きトークンを発行する

mock-oauth2-serverは、トークンリクエストへの`claims`パラメータ
（JSON文字列）を、発行するJWTのペイロードにそのままマージする機能を
持つ。これにより、JSON_CONFIGによるサーバー側の事前設定なしに、
トークンリクエストのたびに任意の非標準クレームを注入できる。

```sh
curl -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials \
  -d client_id=alice \
  -d client_secret=dummy \
  -d 'claims={"tenant_id":"acme"}'
```

演習2-2で確認した「`client_id`がそのまま`sub`クレームになる」という
挙動と組み合わせることで、`sub`（誰か）と`tenant_id`（どのテナントか）
を自由に組み合わせたテストトークンを、サーバー側の設定変更なしに
その場で発行できる。これは実運用のIdPには通常ない挙動（クライアントが
勝手にクレームを詐称できてはならない）であり、mock-oauth2-serverが
「ローカル開発・テストの利便性を最優先した、本番運用を想定しない
モックである」という位置付けであることを象徴している（演習3-6の
問い2で扱う）。

## 演習3-3の解説：JWT検証にtenant_id抽出を追加する

```haskell
verify :: JWKSet -> Text -> ExceptT JWTError IO AuthenticatedUser
verify jwks token = do
  jwt <- decodeCompact (LBS.fromStrict (TE.encodeUtf8 token)) :: ExceptT JWTError IO SignedJWT
  claims <- verifyJWT (defaultJWTValidationSettings (const True)) jwks jwt :: ExceptT JWTError IO TenantClaims
  case subjectOf (tenantClaimsSet claims) of
    Just sub -> pure (AuthenticatedUser sub (TenantId (tenantClaimsTenantId claims)))
    Nothing -> throwError (JWTClaimsSetDecodeError "subクレームがありません")
```

Iteration 2からの変更点は次の2つのみである。

1. `verifyClaims`を`verifyJWT`に変え、戻り値の型注釈を`ClaimsSet`から
   `TenantClaims`に変えた。署名検証・有効期限検証のロジック自体
   （`verifyJWT`の内部実装）はIteration 2と変わらない。ペイロードの
   デコードに使う`FromJSON`インスタンスが`TenantClaims`のものに
   差し替わるだけである。
2. `AuthenticatedUser`の構築時に、`tenantClaimsTenantId claims`から
   取り出した`Text`を`TenantId`でラップして渡すようになった。

`tenant_id`クレームが存在しない場合、`TenantClaims`の`FromJSON`
インスタンスの`o .: "tenant_id"`が失敗し、`verifyJWT`内部での
ペイロードのデコードが失敗する。これは（`subjectOf`のような明示的な
`Nothing`チェックを書かなくても）自動的に`JWTClaimsSetDecodeError`
としてJWTErrorになり、最終的に401（`Auth.Server`の`authHandler`が
`Left`を401に変換する）につながる。単体テスト
「tenant_idクレームがないトークンは拒否される」がこの経路を検証して
いる。

## 演習3-4の解説：ストアのテナント分離を実装する

```haskell
type Store = IORef (Map TenantId (Int, [User]))

newStore :: IO Store
newStore = newIORef Map.empty

server :: Store -> Server API
server store = createUserHandler :<|> listUsersHandler
  where
    createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
    createUserHandler authUser (CreateUserRequest reqName reqEmail) =
      liftIO $ atomicModifyIORef' store $ \tenants ->
        let tenantId = authTenantId authUser
            (nextId, users) = Map.findWithDefault (1, []) tenantId tenants
            newUser = User nextId reqName reqEmail
            tenants' = Map.insert tenantId (nextId + 1, users ++ [newUser]) tenants
        in (tenants', newUser)

    listUsersHandler :: AuthenticatedUser -> Handler [User]
    listUsersHandler authUser = liftIO $ do
      tenants <- readIORef store
      pure (maybe [] snd (Map.lookup (authTenantId authUser) tenants))
```

Iteration 1の`Store`（`IORef (Int, [User])`）は「次に採番するid」と
「登録済みユーザー一覧」のペアを1組しか持たなかった。Iteration 3では
これをテナントID単位に複製し、`Map TenantId (Int, [User])`とすることで、
テナントごとに独立した「次に採番するid」「登録済みユーザー一覧」の組
を持つようにした。

- `createUserHandler`は、リクエストを送ってきたテナント
  （`authTenantId authUser`）に対応するエントリだけを
  `Map.findWithDefault (1, [])`で取り出し（初めてユーザーを登録する
  テナントには`(1, [])`という初期値を与える）、Iteration 1と同じ要領で
  新しい`User`を作る。最後に`Map.insert`でそのテナントのエントリだけを
  更新した新しい`Map`を返す。
- `atomicModifyIORef'`はMap全体（＝全テナント分）を対象に原子的な
  読み書きを行っている。他のテナントの採番と競合しても、
  `atomicModifyIORef'`が保証する単一の原子的操作の中でMap全体を
  読み書きするため、Iteration 1と同様に競合状態は起こらない。
- `listUsersHandler`は該当テナントのエントリを`Map.lookup`で探し、
  見つからなければ（＝そのテナントがまだ誰もユーザーを登録していない
  場合）空リストを返す。

この設計の要点は、「あるテナントのハンドラ実行が、データ構造上、他
テナントのキーに触れる余地がない」ことである。`authTenantId authUser`
以外のキーへの参照は、この関数の中のどこにも書かれていない。バグに
よってテナント分離が破られるとすれば「間違ったキーを渡してしまう」
ことだけであり、「そもそもキーを指定し忘れてすべてのテナントを混ぜて
しまう」というクラスのバグ（Iteration 1のような単一の`(Int, [User])`
のままテナントを見分けずに扱ってしまう）は、`Store`の型を
`Map TenantId (...)`に変えた時点で構造的に起こりえなくなっている。

## 演習3-5の解説：テストをすべてGREENにする

### 単体テストにおけるテナント分離の検証

```haskell
it "別テナントのユーザーは互いに見えない（テナント分離）" $ do
  store <- newStore
  let create :<|> list = server store
  _ <- runHandler (create testUser (CreateUserRequest "Alice" "alice@example.com"))
  Right acmeUsers <- runHandler (list testUser)
  Right globexUsers <- runHandler (list otherTenantUser)
  map userName acmeUsers `shouldBe` ["Alice"]
  globexUsers `shouldBe` []

it "テナントごとにid採番が独立している" $ do
  store <- newStore
  let create :<|> _list = server store
  Right acmeUser <- runHandler (create testUser (CreateUserRequest "Alice" "alice@example.com"))
  Right globexUser <- runHandler (create otherTenantUser (CreateUserRequest "Bob" "bob@example.com"))
  userId acmeUser `shouldBe` 1
  userId globexUser `shouldBe` 1
```

同じ`Store`（同じ`IORef`）に対して、テナントID違いの2つの
`AuthenticatedUser`（`testUser`はacme、`otherTenantUser`はglobex）で
ハンドラを呼び分けている。「別テナントには何も見えない」だけでなく、
「両テナントとも独立してid=1から採番される」ことも確認しており、
テナント分離が単なるフィルタリング（全ユーザーを保持しつつ表示だけ
絞る）ではなく、データそのものが独立していることを保証している。

### 結合テストにおけるテナント分離の検証

```haskell
with app $ describe "POST /users, GET /users（テナント分離）" $
  it "別テナントのトークンでは他テナントが作成したユーザーが見えない" $ do
    _ <- request "POST" "/users" [("Content-Type", "application/json"), authHeader token]
      [json|{name:"Alice",email:"alice@example.com"}|]
    request "GET" "/users" [authHeader otherTenantToken] "" `shouldRespondWith` [json|[]|]
```

`token`・`otherTenantToken`は同じRSA鍵で署名されているが、`tenant_id`
クレームだけが異なる（`signTestToken jwk "acme"`・
`signTestToken jwk "globex"`）。これはHTTP層を含めた end-to-end の
検証であり、「JWTの`tenant_id`クレームが正しく`AuthenticatedUser`経由
で`User.Server`まで伝わり、ストアのキーとして使われている」という
一連の流れ全体を検証している。

## 演習3-6の解説（発展）：実サーバーでの疎通確認・設計の一般化

### mock-oauth2-serverの`claims`パラメータは本番のIdPの挙動ではない

演習3-2で使った`claims`パラメータによる任意のクレーム注入は、
あくまでローカル開発・テストの利便性のためのモック機能である。実際の
IdP（Keycloak等）では、ユーザーがどのテナント（組織・グループ）に
所属するかはIdP側のユーザーデータベース・管理コンソールで管理され、
ログインしたユーザー本人の認証結果に基づいてクレームが発行される。
クライアントがトークンリクエストに任意の`tenant_id`を書けてしまう設計
は、テナント境界を完全に無意味にしてしまう（他社のテナントIDを
指定するだけでデータにアクセスできてしまう）ため、本番運用では
決して許容できない。本教材でこれが許容されているのは、あくまで
「JWTの`tenant_id`クレームを受け取ってからの検証・分離ロジック」を
学ぶことが目的であり、認証サーバー自体の実装は教材のスコープ外である
ためである。

### Iteration 4（永続化層）との接続

DBに置き換える際にテナント分離を維持する代表的な設計は2つある。

- **共有スキーマ＋テナントID列**：全テーブルに`tenant_id`列を持たせ、
  すべてのクエリのWHERE句に`tenant_id = ?`を含める。実装コストは低いが、
  1つのクエリでも`tenant_id`条件を書き漏らすとテナント境界が破れる
  リスクがある（Row Level SecurityのようなDB機能で強制する対策もある）。
- **スキーマ／データベース分離**：テナントごとに別スキーマ・別
  データベースを用意する。分離は強固だが、マイグレーション・接続管理の
  運用コストが増える。

本章で確立した`Map TenantId (...)`という設計は、「共有スキーマ＋
テナントID列」パターンのin-memory版に相当する。Repository層を導入する
際も、`authTenantId`をRepositoryのメソッドの必須引数にする（＝
テナントIDを渡さずにデータへアクセスする経路を型として作れなくする）
という考え方は、Iteration 3の設計をそのまま踏襲できる。
