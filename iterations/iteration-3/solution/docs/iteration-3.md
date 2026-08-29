# Iteration 3：解説

このドキュメントは`../../exercise/docs/iteration-3.md`の演習問題に対応する
解答解説である。見出しの番号（3-1〜3-9）は演習側と対応している。

## 演習3-1の解説：AuthenticatedUserにテナントIDを追加する

```haskell
-- src/Auth/Types.hs
newtype TenantId = TenantId { unTenantId :: Text } deriving (Show, Eq, Ord)

data AuthenticatedUser = AuthenticatedUser
  { authSubject  :: Text
  , authTenantId :: TenantId
  } deriving (Show, Eq)
```

この時点では型を追加しただけで、この`TenantId`をJWTからどう取り出すか
はまだ決めていない（演習3-2で扱う）。`Auth.Server`はまだ古い
`AuthenticatedUser`の作り方（`sub`だけ）のままなので、コンパイルは
通らない。

## 演習3-2の解説：JWTからtenant_idクレームを取り出す

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

`ClaimsSet`はRFC 7519が定義する標準クレーム（`sub`・`exp`等）だけを
持つ型で、`tenant_id`のような独自クレームのフィールドは持たない。
`verifyJWT`はペイロードを任意の`FromJSON`インスタンスとしてパース
できるようになっており、標準クレームに独自クレームを追加した型
（`AuthClaims`）を渡すことで、両方を一度に検証できる。`HasClaimsSet`
インスタンスは、joseの内部処理（`exp`等の検証）が`AuthClaims`からでも
標準クレーム部分を読み書きできるようにするための橋渡しである。
`FromJSON`インスタンスは、まず`Object o`全体を標準の`ClaimsSet`として
パースし（`parseJSON (Object o)`）、さらに同じオブジェクトから
`"tenant_id"`キーを取り出す。`tenant_id`キーが存在しなければ
`o .: "tenant_id"`が失敗し、`AuthClaims`全体のパースが失敗するため、
`verifyJWT`もそのトークンを拒否する（401になる）。

```haskell
-- src/Auth/Server.hs
verify jwks token = do
  jwt <- decodeCompact (...) :: ExceptT JWTError IO SignedJWT
  claims <- verifyJWT (defaultJWTValidationSettings (const True)) jwks jwt :: ExceptT JWTError IO AuthClaims
  case subjectOf (authClaimsSet claims) of
    Just sub -> pure (AuthenticatedUser sub (TenantId (authClaimsTenantId claims)))
    Nothing  -> throwError (JWTClaimsSetDecodeError "subクレームがありません")
```

`verifyJWT`の型註釈を`ClaimsSet`から`AuthClaims`に変えるだけで、
検証対象のペイロードの型が切り替わる。`subjectOf`は`ClaimsSet`に対する
関数なので、`authClaimsSet claims`で中身の`ClaimsSet`を取り出してから
渡す。

## 演習3-3の解説：既存のテストを直す

単体テストは`User.Server.server`を直接呼び出すため、`AuthenticatedUser`
の値をそのままコード上に書いている。フィールドが増えれば、その値の
組み立て方を直接書き換えるだけでよい。

結合テストは実際にJWTを検証するため、テストが組み立てるトークン
自体に`tenant_id`クレームがなければ、`AuthClaims`のパースに失敗して
401になる。`Crypto.JWT`の`addClaim`で非標準クレームをその場で
追加できる。

```haskell
-- test/integration/User/UserSpec.hs
let claims = addClaim "tenant_id" (String tenantId)
           $ emptyClaimsSet
               & claimSub ?~ "alice"
               & claimExp ?~ NumericDate expiresAt
```

## 演習3-4の解説：採番がテナントごとに独立していることを検証する

「異なるテナントでそれぞれ作成すると、両方ともid=1になる」という
テスト1つが、`Map Int User`という1段のMapから`Map TenantId (Int, Map
Int User)`という2段のMapへの構造変更全体を駆動する。

```haskell
-- src/User/Store.hs
newtype Store = Store (IORef (Map TenantId (Int, Map Int User)))

createUser (Store ref) tenantId name email =
  atomicModifyIORef' ref $ \tenants ->
    let (nextId, users) = Map.findWithDefault (1, Map.empty) tenantId tenants
        newUser = User nextId name email
        tenants' = Map.insert tenantId (nextId + 1, Map.insert nextId newUser users) tenants
    in (tenants', newUser)
```

Iteration 1では`Map Int User`（idをキーにしたユーザーの集合）を
`IORef`で1つ持っていた。テナント分離のために、外側にもう1段
`Map TenantId (...)`を被せ、「テナントIDをキーにした、テナントごとの
`(次のid, Map Int User)`の集合」という構造にした。`Map.findWithDefault
(1, Map.empty)`は、まだ1人もユーザーがいないテナントに対しては
「次のidは1、ユーザーは空」として扱う。`atomicModifyIORef'`で外側の
`Map`全体を一括で更新するため、Iteration 1で説明した競合状態の回避は
そのまま保たれる。

## 演習3-5の解説：一覧が自テナントに閉じていることを検証する

`listUsers`は`createUser`と同じ`Map TenantId (...)`から、指定した
`tenantId`に対応する`Map Int User`だけを取り出して返す。演習3-4の
変更がすでにこの形になっていれば、このテストは追加の実装なしで
GREENになる。

## 演習3-6の解説：単一取得がテナント境界を越えないことを検証する

```haskell
-- src/User/Server.hs
getUserHandler authUser uid = do
  maybeUser <- liftIO (getUser store (authTenantId authUser) uid)
  case maybeUser of
    Just u  -> pure u
    Nothing -> throwError err404
```

`getUser`は指定したテナントの`Map Int User`の中だけを探すため、
「そのidが存在しない」場合と「そのidは存在するが別テナントのものだ」
場合を、呼び出し側は区別できない（どちらも`Nothing`が返る）。この
区別をしないことが重要で、もし区別してエラーメッセージを変えると、
「そのidは存在するが権限がない」という情報が、そのidの存在自体を
教えてしまうことになる。

## 演習3-7の解説：結合テストで同じ振る舞いを確認する

単体テスト（演習3-4〜3-6）ですでに`User.Store`・`User.Server`の実装を
終えているため、結合テストはHTTP経由でも同じ振る舞いになっていることを
確認するだけになる。

## 演習3-8の解説：単体テストと結合テストへの影響を考える

問い1の答え：単体テストは`User.Server.server`を直接呼び出すため、
JWTの検証を経由しない。`AuthenticatedUser`の値はコード上の直値であり、
その型（引数の数）が変わればコンパイルエラーとして即座に検出される。
結合テストは実際にJWTの検証（`Auth.Server.verifyToken`）を経由する
ため、型としては何も変わっていなくても（`Text`のJSON値である
`tenant_id`クレームは元々あってもなくても同じ`Value`型として送れて
しまうため）、コンパイルエラーにはならず、検証ロジックが実行時に
拒否する形で失敗が現れる。

問い2の答え：Iteration 2と同じ理由で説明がつく。`Health.Api`には
`AuthProtect`が付いておらず、`Health`のserver値・単体/結合テスト用の
Applicationのいずれも`Auth`・`User`のどちらのモジュールにも依存しない
ため、テナント分離の変更が一切波及しない。

## 使用ライブラリ

Iteration 2からの追加はない。`Data.Map.Strict`のネストしたMapを
テナント分離に応用した点が新しい。
