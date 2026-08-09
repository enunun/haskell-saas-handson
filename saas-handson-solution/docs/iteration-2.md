# Iteration 2：解説

このドキュメントは`saas-handson/docs/iteration-2.md`の演習問題に対応する
解答解説である。見出しの番号（2-1〜2-6）は演習側と対応している。

## 設計判断：認証を自前実装しないという選択

ROADMAPのIteration 2は「Basic認証またはトークン認証によるAPIアクセス
制御」としていたが、本教材ではさらに一歩進めて「認証サーバー自体を
外部サービスに任せ、アプリケーションはトークンの検証だけを行う」という
構成を取った。パスワードのハッシュ化・保管、ログイン画面、パスワード
リセットといった認証まわりの実装・運用コストは大きく、toB SaaSの
バックエンドが自前で背負う必然性は薄い。現実のプロダクトでも
Auth0・Keycloak・Cognitoのような外部IdP（Identity Provider）にログイン
機能自体を委譲し、アプリケーションは発行されたJWTを検証するだけ、という
構成が主流である。

ローカル開発・演習では実際のIdPを使う代わりに、
[mock-oauth2-server](https://github.com/navikt/mock-oauth2-server)
（Navikt製、Apache License 2.0）をDockerで起動する。実際のログイン・
同意画面なしに任意の`client_id`でJWTを即座に発行できる、ローカル開発・
テスト専用のモックサーバーである。`docker-compose.yml`（リポジトリ
ルート）に定義してある。

```yaml
services:
  app:
    build:
      context: .
      dockerfile: .devcontainer/Dockerfile
    # ...
    depends_on:
      - mock-auth

  mock-auth:
    image: ghcr.io/navikt/mock-oauth2-server:2.1.10
    ports:
      - "8081:8080"
```

このリポジトリのdevcontainer（`.devcontainer/devcontainer.json`）は
`dockerComposeFile`でこの`docker-compose.yml`を参照しており、`app`
サービス（devcontainer本体）と`mock-auth`サービスが同じdocker compose
ネットワーク上に一緒に起動する。VS CodeでこのDev Containerを開く
（＝このコンテナに入る）と、追加のセットアップなしに`mock-auth`という
サービス名・コンテナ内ポート8080でmock-oauth2-serverにアクセスできる。
`docker compose up`を利用者が別途叩く必要はない。

アプリケーション側（`saas-handson-solution`）が担うのは以下の2点のみで
ある。

1. 起動時にmock-oauth2-serverのJWKS（JSON Web Key Set）を取得し、署名
   検証用の公開鍵として保持する。
2. リクエストの`Authorization: Bearer <token>`ヘッダのJWTを検証し、
   `sub`クレームを取り出して「誰がアクセスしているか」を表す
   `AuthenticatedUser`型の値として後続のハンドラに渡す。

## 演習2-1の解説：認証の仕組みを読み解く

### `AuthProtect`：汎用認証コンビネータ

```haskell
type API =
       AuthProtect "jwt" :> "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> AuthProtect "jwt" :> "users" :> Get '[JSON] [User]
```

`ReqBody`・`PostCreated`はいずれもリクエスト・レスポンスの「データの
形」を型で表現するコンビネータだった。`AuthProtect`はそれらと異なり、
「このエンドポイントに到達する前に、どういう検証ロジックを通すか」を
表現する。Basic認証専用の`BasicAuth`コンビネータと違い、`AuthProtect`は
任意の認証方式（本教材ではJWT Bearer認証）を差し込める汎用の仕組みで、
`"jwt"`という型レベル文字列タグによって、どの検証ロジック・どの戻り値の
型と結び付くかを指定する。

### `AuthServerData`型族：タグと戻り値の型を結び付ける

```haskell
type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser
```

（`src/Auth/Types.hs`）

`AuthServerData`はServantが用意するopenな型族（type family）で、
「`AuthProtect`のタグごとに、認証成功時にどんな型の値が得られるか」を
定義する。この`type instance`宣言がないと何が起きるか：`servant-server`
は`AuthProtect "jwt" :> api`に対する`HasServer`インスタンスを、
`HasContextEntry context (AuthHandler Request (AuthServerData
(AuthProtect "jwt")))`という制約付きで提供している。`AuthServerData
(AuthProtect "jwt")`が具体的な型に解決できなければ、
`createUserHandler`・`listUsersHandler`の型を`AuthenticatedUser -> ...`
にすることも、`Context`に`AuthHandler Request AuthenticatedUser`を積む
こともできず、コンパイルが通らない。この宣言が「`"jwt"`というタグの
認証を通過すると`AuthenticatedUser`が手に入る」という約束をコンパイラに
教えている。

### `serveWithContext`と`Context`

```haskell
mkApp :: JWKStore -> Store -> Application
mkApp jwkStore store = serveWithContext api (authContext jwkStore) (mkServer store)
```

（`src/Server.hs`）

`serve`はAPIの型と実装（`Server API`）だけからWAIの`Application`を作る
が、`AuthProtect`のような「実行時の追加設定」（ここでは検証に使う
`AuthHandler`）を必要とするコンビネータは`serve`だけでは組み立てられ
ない。`serveWithContext`はAPIの型・実装に加えて`Context`という異種
リストを受け取り、そこに`AuthHandler Request AuthenticatedUser`
（`Auth.Server.authContext`が構築する）を積むことで、`AuthProtect "jwt"`
を解決できるようにする。

### HealthはAuthProtect対象外

`src/Api.hs`のHealthエンドポイント（`"health" :> Get '[JSON]
HealthResponse`）には`AuthProtect "jwt"`を付けていない。Userの2つの
エンドポイントのみに付けたことで、Healthは引き続き認証なしでアクセス
でき、Userは認証必須になる。この非対称性は意図的なもので、ヘルスチェック
はロードバランサ・オーケストレータから認証情報なしで叩かれる前提で
あるのに対し、ユーザー登録・一覧はビジネスデータであり保護が必要である
ため。1つのAPI型の中で機能ごとに異なる認証要件を型で表現できる、という
点もServantの型レベルAPI設計の利点である。

## 演習2-2の解説：外部認証サーバーとの疎通確認

mock-oauth2-serverはデフォルト設定で`default`というissuer（発行者）を
持ち、`/default/token`エンドポイントで`client_credentials`グラントの
トークン発行に応答する。実際のOAuth2クライアント資格情報グラントとは
異なり、`client_secret`の値は検証されない。`client_id`に指定した値が
そのままJWTの`sub`（subject）クレームになる、というのがこのモック
サーバーの最大の特徴であり、「本物のログイン画面なしに、任意のユーザー
としてトークンを即座に取得できる」という開発体験を実現している。

`/default/jwks`は、発行したJWTの署名を検証するための公開鍵一覧
（JWKS、RFC 7517）を公開するエンドポイントである。`src/Auth/Server.hs`
の`newJWKStore`はこれをアプリケーション起動時に一度だけ取得する。

```haskell
newJWKStore :: String -> IO JWKStore
newJWKStore jwksUri = do
  req <- setRequestCheckStatus <$> parseRequest jwksUri
  JWKStore . getResponseBody <$> httpJSON req
```

本来はOIDCのdiscoveryドキュメント（`/.well-known/openid-configuration`）
の`jwks_uri`フィールド経由でJWKS URIを解決するのが一般的だが、本教材
では簡略化のためJWKS URIを`Main.hs`に直接ハードコードしている
（演習2-6で発展課題として扱う）。

## 演習2-3の解説：JWT検証ロジックを実装する

```haskell
verify :: JWKSet -> Text -> ExceptT JWTError IO AuthenticatedUser
verify jwks token = do
  jwt <- decodeCompact (LBS.fromStrict (TE.encodeUtf8 token)) :: ExceptT JWTError IO SignedJWT
  claims <- verifyClaims (defaultJWTValidationSettings (const True)) jwks jwt
  case subjectOf claims of
    Just sub -> pure (AuthenticatedUser sub)
    Nothing -> throwError (JWTClaimsSetDecodeError "subクレームがありません")

subjectOf :: ClaimsSet -> Maybe Text
subjectOf claims = claims ^? claimSub . _Just . string
```

### `decodeCompact`：コンパクト表現のデコード

JWTは`ヘッダ.ペイロード.署名`という3パートをピリオドで連結した
「コンパクト表現」の文字列である（jose・JWSの仕様上はコンパクト表現以外
の直列化もあるが、通常のJWTはこの形式）。`decodeCompact`はこの文字列を
パースして`SignedJWT`型の値（署名済みJWSオブジェクト）にする。この時点
ではまだ署名の正当性は検証していない。

### `verifyClaims`：署名検証とクレーム検証を一括で行う

`verifyClaims`は「署名がJWKSetの鍵のいずれかで検証できるか」
（cryptographicな検証）と「`exp`（有効期限）・`nbf`（有効開始時刻）・
`aud`（audience）・`iss`（issuer）といったクレームが妥当か」
（ビジネスルール上の検証）の両方を一度に行う。`jose`ライブラリの
`VerificationKeyStore`型クラスには`JWKSet`のインスタンスが用意されて
おり（`Crypto.JOSE.JWK.Store`）、含まれる鍵を順に試して署名検証する。
本教材のJWKSetは1鍵構成のため`kid`（Key ID）による鍵の絞り込みは行って
いない。

`defaultJWTValidationSettings`はaudienceの検証述語を引数に取る
（RFC 7519は`aud`クレームを持つJWTを受け取ったアプリケーションは自身が
audienceに含まれるかを検証すべきとしている）。本教材では簡略化のため
`const True`（常に許可）としているが、これは実務では避けるべき単純化で
あり、演習2-6で扱う。

### `subjectOf`：Lens・Prismによるクレームの取り出し

`claimSub`は`ClaimsSet`から`Maybe StringOrURI`を取り出す`Lens'`、
`string`は`StringOrURI`から`Text`を取り出せる場合だけ`Just`を返す
`Prism'`である。`claims ^? claimSub . _Just . string`は、
「`claimSub`で`Maybe StringOrURI`を取り出し、`Just`であれば中身を取り出し
（`_Just`）、それが`Arbitrary`な文字列であれば`Text`として取り出す
（`string`）」という一連の操作を、失敗しうる`(^?)`（`preview`）で合成
したものである。`sub`クレームが存在しない、または`":"`を含むもののURI
としてパースできない不正な文字列である場合、`subjectOf`は`Nothing`を
返す。

### 型注釈が必要な理由

`decodeCompact`の呼び出しに`:: ExceptT JWTError IO SignedJWT`という型
注釈を付けている。`decodeCompact`・`verifyClaims`はいずれもエラー型`e`に
ついて多相的（`AsError e`・`AsJWTError e`があれば任意の`e`で使える）で
あり、注釈なしでは`e`を一意に決定できずコンパイルエラーになる
（曖昧な型変数）。`runJOSE`で最終的に`Either JWTError a`を得るために、
どこかで`e`を`JWTError`に固定する必要がある。

## 演習2-4の解説：テストをすべてGREENにする

### 単体テストが外部サービスに依存しない設計

`test/unit/Auth/AuthSpec.hs`はdocker-composeで起動するmock-oauth2-server
を一切必要としない。テストコードの中で`Crypto.JOSE.genJWK`によりその場
でRSA鍵ペアを生成し、`signClaims`で自前のJWTに署名している。

```haskell
jwk <- genJWK (RSAGenParam (2048 `div` 8))
now <- getCurrentTime
token <- signToken jwk (addUTCTime 3600 now)
result <- verifyToken (mkJWKStore (JWKSet [jwk])) token
result `shouldBe` Right (AuthenticatedUser "alice")
```

`Auth.Server`の`mkJWKStore :: JWKSet -> JWKStore`は、ネットワーク越しに
JWKSを取得する`newJWKStore`とは別に用意した、既知の`JWKSet`から直接
`JWKStore`を組み立てる関数である。実運用では`newJWKStore`（HTTP経由）
のみを使うが、テストでは`mkJWKStore`（純粋な値の注入）を使うことで、
外部プロセスへの依存・ネットワークの不安定さからテストを切り離して
いる。「登録されていない鍵で署名されたトークンは拒否される」テストは、
署名に使った鍵とは別の鍵だけを含む`JWKSet`を検証に使うことで、
`verifyClaims`が正しくすべての鍵を試したうえで失敗することを確認して
いる。

### 認証層とドメインロジック層の独立

`test/integration/User/UserSpec.hs`を2つの`describe`ブロックに分けて
いる。

- 「認証あり」：有効なJWTを付けたリクエストが正しくデータを操作できる
  ことを検証する。`createUserHandler`・`listUsersHandler`（ドメイン
  ロジック）の実装まで完了して初めてGREENになる。
- 「認証なし・不正トークン」：`Authorization`ヘッダがない、または壊れた
  トークンの場合に401が返ることを検証する。これは`Auth.Server`の
  `authHandler`（`AuthProtect`のルート解決の一部として、ハンドラ本体に
  到達する前に走る）だけで完結する検証であり、`createUserHandler`・
  `listUsersHandler`の実装状況に関係なくGREenにできる（実際、
  `saas-handson`側でこれらが未実装のままでも「Authorizationヘッダなし」
  のテストは最初からGREENになる）。

`AuthProtect`による認証は、Servantのルーティング解決の一部として
ハンドラ本体より先に評価される。そのため認証エラー（401）はハンドラの
ビジネスロジックとは独立して検証・保証できる、というのがこのテスト
構成で確認できる設計上の利点である。

## 演習2-5の解説（発展）：実サーバーでの疎通確認

`cabal run saas-handson-solution`は起動時に`newJWKStore`でmock-oauth2-server
の`http://mock-auth:8080/default/jwks`からJWKSを取得する
（`app/Main.hs`の`jwksUri`）。`mock-auth`はdevcontainerを開いた時点で
docker composeの`depends_on`により先に起動しているため、通常は追加の
準備なしにこの名前解決・接続が成功する。仮にmock-authコンテナが停止して
いる状態でアプリを起動すると、`newJWKStore`内の`parseRequest`・
`httpJSON`がHTTP接続に失敗し、アプリの起動自体が失敗する。これは意図的
な設計で、起動時にJWKSを取得できない状態でサーバーだけ立ち上げてしまう
と、すべてのリクエストが原因不明の500になってしまう事態を防いでいる。

## 演習2-6の解説（発展）：設計の一般化・トラブルシューティング

### audienceの検証

`aud`クレームの検証を厳密に行うには、`defaultJWTValidationSettings`に
渡す述語を`const True`から、実際に許可したいaudience文字列との比較に
変更する。

```haskell
defaultJWTValidationSettings (\aud -> preview string aud == Just "saas-handson")
```

マルチテナントで複数のクライアントアプリケーションが同じ認証サーバーを
共有する場合など、audienceの検証は「このトークンは本当に自分向けに
発行されたものか」を保証する重要なステップになる。

### discoveryドキュメント経由でのJWKS URI解決

`newJWKStore`をdiscoveryドキュメント経由にするには、まず
`/.well-known/openid-configuration`をGETしてJSONの`jwks_uri`フィールド
を取り出し、そのURIに対して改めてGETするという2段階の処理に書き換える
ことになる。`aeson`の`Object`から`.:`で`jwks_uri`フィールドを取り出す
処理を挟むだけでよく、`Network.HTTP.Simple.httpJSON`をもう一度呼び出す
構造は変わらない。

### Iteration 3への接続

`AuthenticatedUser`は現時点で`authSubject :: Text`（`sub`クレーム）しか
保持していない。Iteration 3（マルチテナント対応）でテナントIDを型に
持ち込む際は、JWTの`aud`クレームや、mock-oauth2-serverのJSON_CONFIGで
自由に追加できる独自クレーム（例：`tenant_id`）を`AuthenticatedUser`に
追加フィールドとして取り込み、`ClaimsSet`の`unregisteredClaims`
（またはサブタイプを定義してのカスタムクレームパース、
`Crypto.JWT`の`$subtypes`節を参照）から取り出す形が自然な拡張になる。
