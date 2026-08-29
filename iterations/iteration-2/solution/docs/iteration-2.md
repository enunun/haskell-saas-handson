# Iteration 2：解説

このドキュメントは`../../exercise/docs/iteration-2.md`の演習問題に対応する
解答解説である。見出しの番号（2-1〜2-7）は演習側と対応している。

## 演習2-1の解説：Auth層を読み解く

### `AuthServerData`型族

```haskell
-- src/Auth/Types.hs
type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser
```

Servantの`AuthProtect tag`は「`tag`というタグの付いた認証」を表す
型レベルの印にすぎず、それ自体は認証成功時にどんな値が得られるかを
知らない。`AuthServerData`はオープンな型族（`Servant.Server.Experimental.Auth`
が定義する）で、この関連付けを与えることで、`AuthProtect "jwt" :> API`
というAPI型に対応するハンドラの型が自動的に
`AuthenticatedUser -> ...`になる。この`type instance`宣言がなければ、
`AuthProtect "jwt"`を含むAPI型に対して`Server`型を計算しようとした
時点でコンパイルエラーになる（「`"jwt"`というタグの認証が成功したら
何を渡せばいいのか」をコンパイラが知らないため）。

### `verify`が失敗するケース

```haskell
-- src/Auth/Server.hs
verify jwks token = do
  jwt <- decodeCompact (...) :: ExceptT JWTError IO SignedJWT
  claims <- verifyJWT (defaultJWTValidationSettings (const True)) jwks jwt :: ExceptT JWTError IO ClaimsSet
  case claims ^? claimSub . _Just . string of
    Just sub -> pure (AuthenticatedUser sub)
    Nothing  -> throwError (JWTClaimsSetDecodeError "subクレームがありません")
```

`Left`になるケース：(1) `decodeCompact`がトークン文字列をJWTとして
パースできない（構文自体が壊れている）。(2) `verifyJWT`が、
`jwks`に含まれるどの鍵でも署名を検証できない（改ざん・別の鍵で署名
されている）。(3) `verifyJWT`が、有効期限（`exp`）切れなどクレームの
妥当性検証に失敗する。(4) 検証は通ったが`sub`クレームが存在しない
（`JWTClaimsSetDecodeError`を自分で投げているケース）。

### `newJWKStore`と`mkJWKStore`

`newJWKStore`はJWKS URIに実際にHTTPリクエストを送るため、本番運用時
（`app/Main.hs`）で使う。`mkJWKStore`は既知の`JWKSet`をそのまま包む
だけでネットワークアクセスを伴わないため、テストで固定の鍵ペアを
注入するのに使う。単体テスト・結合テストのいずれも外部サービスに
依存してはならないという方針（`docs/haskell-reference`参照）に、
この使い分けが対応している。

### `AuthHandler`が呼ばれるタイミング

`check :: Request -> Handler AuthenticatedUser`は、Servantのルーティング
がどのエンドポイントにマッチするかを決めた**後**、そのエンドポイントの
本来のハンドラ（`createUserHandler`等）を呼び出す**前**に実行される。
`AuthProtect "jwt"`はAPI型の一部であり、ルーティング自体はパス・
メソッドだけで先に決まる。認証はマッチしたエンドポイントに対する
「前段の関門」として働く。

## 演習2-2の解説：User.ApiにAuthProtectを追加する

```haskell
-- src/User/Api.hs
type API =
       AuthProtect "jwt" :> "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> AuthProtect "jwt" :> "users" :> Get '[JSON] [User]
  :<|> AuthProtect "jwt" :> "users" :> Capture "id" Int :> Get '[JSON] User
```

`AuthProtect "jwt"`をAPI型の各エンドポイントの先頭に置くと、対応する
ハンドラの型の先頭に`AuthenticatedUser ->`が追加される（`AuthServerData`
の関連付けにより）。この時点では`User.Api`の型しか変えていないため、
`User.Server`はまだ古い型のままであり、コンパイルは通らない。

## 演習2-3の解説：ハンドラの型を合わせる

```haskell
-- src/User/Server.hs
createUserHandler :: AuthenticatedUser -> CreateUserRequest -> Handler User
createUserHandler _authUser req = liftIO (createUser store (crName req) (crEmail req))

listUsersHandler :: AuthenticatedUser -> Handler [User]
listUsersHandler _authUser = liftIO (listUsers store)

getUserHandler :: AuthenticatedUser -> Int -> Handler User
getUserHandler _authUser uid = ...
```

3つのハンドラすべてに`AuthenticatedUser ->`を追加する。現時点では
`AuthenticatedUser`を受け取るだけで中身は使わない（`_authUser`と
アンダースコア始まりの名前にして、未使用であることを明示している）。
「誰か」によって振る舞いを変える機能（テナント分離・権限判定）は、
それぞれIteration 3・Iteration 5で追加する。

型シグネチャの変更だけで、`User.Server`を呼び出していた既存のテストが
コンパイルエラーになるのは、Haskellの型システムが「引数の数・型が
合っているか」をコンパイル時に強制するためである。実行時に初めて
気づく不整合ではなく、ビルドの時点で機械的に検出できる。

## 演習2-4の解説：既存のテストを認証に対応させる

### 単体テスト

```haskell
-- test/unit/User/UserSpec.hs
testUser :: AuthenticatedUser
testUser = AuthenticatedUser "alice"
```

単体テストは`User.Server.server`を直接呼び出すため、JWTの検証
（Auth層）を経由しない。「認証を通過した後の値」を直接組み立てて
渡せば十分である。

### 結合テスト

```haskell
-- test/integration/User/UserSpec.hs
jwk <- runIO (genJWK (RSAGenParam (2048 `div` 8)))
...
pure (serveWithContext (Proxy :: Proxy User.API) (authContext (mkJWKStore (JWKSet [jwk]))) (server store))
```

結合テストはHTTPレベルで検証するため、実際に`Authorization`ヘッダを
読み取ってJWTを検証する経路（`Auth.Server`）を通る。`runIO`は
`Spec`を組み立てる段階（テスト実行前の1回だけ）で`IO`アクションを
実行するためのhspecの機能で、テストケースごとに鍵を作り直さずに
済む。`genJWK`でその場でRSA鍵ペアを生成し、`mkJWKStore`でその鍵**だけ**
を含む`JWKSet`を検証側に渡すため、外部の認証サーバーには一切
接続しない。

`authHeader`は`Network.HTTP.Types.Header`
（`(CI ByteString, ByteString)`）を返すヘルパーで、`OverloadedStrings`
により文字列リテラルがそのまま`CI ByteString`になる。

新しく追加した2つのテストケース（`Authorization`ヘッダなし／不正な
トークン）は、`Auth.Server.authHandler`が`err401`を投げる経路を
それぞれ検証している。

## 演習2-5の解説：トップレベルの配線

```haskell
-- src/Server.hs
mkApp :: JWKStore -> Store -> Application
mkApp jwkStore store = serveWithContext api (authContext jwkStore) (mkServer store)
```

`AuthProtect`を使うAPIを`serve`できない（`serve`は`Context '[]`しか
持たないため）。`serveWithContext`は`HasServer`の証拠に加えて
`Context`を受け取れるバージョンで、`Auth.Server.authContext`が
`AuthHandler Request AuthenticatedUser`を含む`Context`を提供する。
Healthは`AuthProtect`を持たないため、この`Context`の影響を受けない
（引き続き認証なしでアクセスできる）。

## 演習2-6の解説：単体テスト・結合テストへの影響を考える

問い1の答え：単体テストは`User.Server.server`を直接呼び出すため、
HTTPリクエストの受信・`Authorization`ヘッダのパース・JWT検証という
Web層を一切経由しない。そのため「認証を通過した後の値」を直接組み立て
れば十分である。結合テストは`serveWithContext`が生成したApplicationに
対して実際にHTTPリクエストを送るため、`Authorization`ヘッダの読み取り
からJWT検証まで、認証の経路全体を検証できる（できなければならない）。

問い2の答え：`Health.Api`には`AuthProtect`が付いておらず、
`Health.Server.server`・`Health`単体の結合テスト用Applicationのいずれも
`Auth`モジュールに一切依存しないため。Vertical Slice構成により、
Userに認証を追加する変更が、無関係なHealthのテストに一切波及しない。

## 使用ライブラリ

| ライブラリ | 役割 |
|---|---|
| jose | JWTのデコード・署名検証（`Crypto.JWT`）、テストでの鍵生成・署名（`Crypto.JOSE`） |
| lens | `Crypto.JWT`の`ClaimsSet`から`^?`・`&`・`?~`でクレームを読み書きする |
| http-conduit | `newJWKStore`がJWKS URIにHTTPリクエストを送るための`Network.HTTP.Simple` |
