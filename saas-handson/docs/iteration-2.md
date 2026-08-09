# Iteration 2：演習

## この章で作るもの

`POST /users`・`GET /users`に認証を必須にする。認証は自前で実装せず、外部の
認証サーバーが発行したJWT（JSON Web Token）をアプリケーション側で検証する
方式を取る。ローカル開発・演習用の認証サーバーとしてmock-oauth2-server
（Dockerイメージ）を使う。このリポジトリのdevcontainer
（`.devcontainer/devcontainer.json`）はdocker composeベースになっており、
`docker-compose.yml`の`app`サービス（＝このコンテナ自身）と`mock-auth`
サービスが同じネットワーク上で一緒に起動する。つまりVS CodeでこのDev
Containerを開いた（＝このコンテナに入った）時点でmock-auth2-serverは
すでに動いており、コンテナ内から`mock-auth`というホスト名でアクセス
できる（`docker compose up`を別途自分で叩く必要はない）。`GET /health`は
引き続き認証なしでアクセスできるままにする（ロードバランサ等の死活監視は
認証なしで叩かれる前提のため）。

`AuthenticatedUser`という型が導入され、認証を通過したリクエストのハンドラ
には必ずこの型の値が渡ってくるようになる。「誰がアクセスしているか」を
型で表現するというテーマは、Iteration 3（マルチテナント対応）・
Iteration 5（権限管理）でも土台として使う。

## 進め方

演習は2-1（型・仕組みを読み解く）→2-2（外部認証サーバーとの疎通確認）→
2-3（JWT検証ロジックの実装）→2-4（テスト全体の確認）→2-5・2-6（発展）と
いう順で積み上げる。詰まった場合は`saas-handson-solution/docs/iteration-2.md`
の対応する節を参照する。コマンドはリポジトリルート
（`cabal.project`のある場所）から実行する。

## 演習2-1：認証の仕組みを読み解く

以下のファイルはすでに完成しており変更不要である。これらを読み、
下記の問いに自分の言葉で答えられるようにする（コードを書く必要はない）。

- `src/Auth/Types.hs`
- `src/User/Api.hs`
- `src/Server.hs`

```haskell
newtype AuthenticatedUser = AuthenticatedUser
  { authSubject :: Text
  } deriving (Show, Eq)

type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser
```

```haskell
type API =
       AuthProtect "jwt" :> "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> AuthProtect "jwt" :> "users" :> Get '[JSON] [User]
```

```haskell
mkApp :: JWKStore -> Store -> Application
mkApp jwkStore store = serveWithContext api (authContext jwkStore) (mkServer store)
```

1. `AuthProtect "jwt"`はServantの型レベルAPIの中でどういう役割を持つか。
   `ReqBody`・`PostCreated`といったこれまで見てきたコンビネータと比べて、
   何が違うか。
2. `type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser`
   という宣言がないと何が起きるか。`src/User/Server.hs`の
   `createUserHandler`・`listUsersHandler`の型と結び付けて考える。
3. `serve`ではなく`serveWithContext`を使う理由は何か。渡している
   `authContext jwkStore`は何のために必要か。
4. `Health.Api`（あるいは`src/Api.hs`の`"health"`エンドポイント）には
   `AuthProtect "jwt"`が付いていない。これによってHealthとUserの認証要否
   はどう変わるか。

## 演習2-2：外部認証サーバーとの疎通確認

本教材では認証サーバーとしてmock-oauth2-server（Dockerイメージ）を使う。
自前でパスワード管理・ログイン画面を実装せず、JWTの発行だけを外部サービス
に任せ、アプリ側はJWTの検証だけを行う構成である。

このコンテナ（devcontainer）の中から、`mock-auth`というホスト名・
コンテナ内ポート8080で直接アクセスできる。以下のコマンドはこのコンテナに
入った状態のターミナルで実行する。

1. `client_credentials`グラントでトークンを取得する
   （`client_id`の値がそのままJWTの`sub`クレームになる）。

```sh
curl -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials \
  -d client_id=alice \
  -d client_secret=dummy
```

レスポンスJSONの`access_token`フィールドの値がJWT本体である。試しに
[jwt.io](https://jwt.io)相当の知識でヘッダ・ペイロード部分（`.`区切りの
1〜2番目）をbase64url decodeしてみて、`sub`・`exp`クレームが入っている
ことを確認する。

2. JWKS（JSON Web Key Set、署名検証用の公開鍵一覧）エンドポイントを確認
   する。

```sh
curl http://mock-auth:8080/default/jwks
```

`src/Auth/Server.hs`の`newJWKStore`はこのエンドポイントをアプリ起動時に
一度だけ取得し、以降のJWT署名検証に使う（`app/Main.hs`の`jwksUri`を
参照）。

（devcontainerの外、つまりホストマシンから直接mock-auth2-serverを叩き
たい場合は`docker-compose.yml`で`localhost:8081`にポートを公開している
ので、そちらを使う。）

## 演習2-3：JWT検証ロジックを実装する

`src/Auth/Server.hs`の`verify`を実装する。

```haskell
verify :: JWKSet -> Text -> ExceptT JWTError IO AuthenticatedUser
verify _jwks _token = error "TODO: Iteration 2で実装する"
```

- 引数のトークンはコンパクト表現（`xxx.yyy.zzz`形式）の文字列である。
  `Crypto.JWT`の`decodeCompact`でデコードする。
- デコードした`SignedJWT`を、起動時に取得済みのJWKSetに対して
  `Crypto.JWT.verifyClaims`で検証する。署名が正しいか、有効期限
  （`exp`クレーム）が切れていないかはこの関数がまとめて検証してくれる。
  `defaultJWTValidationSettings`で検証設定を作る際、audience（`aud`）
  チェックの述語を渡す必要があるが、本教材ではaudienceの検証は行わない
  簡略化とする（`const True`を渡せばよい）。
- 検証を通過した`ClaimsSet`から`sub`クレームを取り出し、
  `AuthenticatedUser`に詰めて返す。`sub`クレームは`Crypto.JWT.claimSub`
  （`Maybe StringOrURI`を指す`Lens'`）と、`Control.Lens`の`(^?)`・
  `_Just`、`Crypto.JWT.string`（`StringOrURI`から`Text`を取り出す
  `Prism'`）を組み合わせて取り出す。
- `sub`クレームが存在しない場合はエラーとして扱う
  （`Crypto.JWT.JWTClaimsSetDecodeError`が使える）。

```sh
cabal test saas-handson --test-options='--match "Auth"'
```

を実行し、`test/unit/Auth/AuthSpec.hs`の4件（有効なトークン・期限切れ・
未登録の鍵・壊れたトークン文字列）がすべてGREENになることを確認する。
このテストは外部プロセス（docker-composeで立てたmock-oauth2-server）を
一切使わず、テストコード内でその場で鍵ペアを生成してJWTに署名している
点に注目する。JWT検証ロジックはHTTPリクエストの表現から独立しているため、
ネットワークなしで高速に検証できる。

## 演習2-4：テストをすべてGREENにする

```sh
cabal test saas-handson
```

を実行する。演習2-3の時点でまだ`healthHandler`（Iteration 0）・
`createUserHandler`・`listUsersHandler`（Iteration 1）が未実装であれば
それらは引き続きREDのままでよいが、認証まわりについては以下がGREENに
なっていることを確認する。

- `test/unit/Auth/AuthSpec.hs`の4件すべて。
- `test/integration/User/UserSpec.hs`の「Authorizationヘッダなしの
  GET /usersは401を返す」「不正なトークンでのGET /usersは401を返す」の
  2件（`createUserHandler`・`listUsersHandler`が未実装でも、認証チェック
  自体は先に走るためGREENになる）。

`test/integration/User/UserSpec.hs`の「認証あり」グループ（POST /users
やGET /usersが200・201を返すテスト）は、Iteration 1の実装
（`createUserHandler`・`listUsersHandler`の中身）も完了して初めて
GREENになる。認証層とドメインロジック層が独立してテストできている
ことを確認する。

## 演習2-5（発展）：実サーバーでの疎通確認

1. このコンテナの中で（別ターミナルを開くか、`&`でバックグラウンド
   実行して）サーバーを起動する。mock-authサービスはdevcontainerを開いた
   時点ですでに起動しているので、追加の準備は不要である。

```sh
cabal run saas-handson
```

2. さらに別のターミナルからこのコンテナに入り、トークンを取得して
   `POST /users`・`GET /users`を叩く。

```sh
TOKEN=$(curl -s -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials -d client_id=alice -d client_secret=dummy \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl -X POST http://localhost:8080/users \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com"}'

curl http://localhost:8080/users -H "Authorization: Bearer $TOKEN"
```

（アプリ自身は同じコンテナの中で動いているので`localhost:8080`のまま。
mock-authは別コンテナなので`mock-auth:8080`という違いに注意する。）

3. `Authorization`ヘッダを付けずに同じリクエストを送り、401が返ることを
   確認する。

## 演習2-6（発展）：設計の一般化・トラブルシューティング

1. 本教材ではaudience（`aud`クレーム）の検証を省略した
   （`defaultJWTValidationSettings (const True)`）。実務ではAPIごとに
   発行対象を限定するのが望ましい。`docker-compose.yml`のコメントを参考に
   発行されたJWTの`aud`クレームの値を確認し、`verify`の中で
   特定の値のみを許可するように変更してみる。
2. 本教材ではJWKS URIを`Main.hs`に直接ハードコードしている
   （discoveryドキュメント`/.well-known/openid-configuration`は経由
   していない）。`http://mock-auth:8080/default/.well-known/openid-configuration`
   の中身を`curl`で確認し、discoveryドキュメント経由で`jwks_uri`を
   解決するように`newJWKStore`を書き換えるとしたら、どのような変更が
   必要か設計してみる。
3. Iteration 3（マルチテナント対応）では、`AuthenticatedUser`が保持する
   情報（現状は`sub`クレームのみ）をテナント識別にどう使えるか、
   `aud`・`iss`クレームや独自クレームの利用も含めて考えてみる。

### 実装時に必要になるLANGUAGE拡張・依存パッケージ

| 用途 | 拡張／依存 |
|---|---|
| `AuthProtect "jwt"`のような型レベルの文字列タグ | `{-# LANGUAGE DataKinds #-}` |
| `type instance AuthServerData (AuthProtect "jwt") = ...` | `{-# LANGUAGE TypeFamilies #-}` |
| JWTのデコード・検証・署名（`Crypto.JWT`） | `jose`パッケージ |
| `Crypto.JWT`の`Lens'`・`Prism'`操作（`(^?)`・`_Just`・`view`等） | `lens`パッケージ |
| `ExceptT`・`throwError`（`Control.Monad.Except`） | `mtl`パッケージ |
| JWKS URIへのHTTP GET（`Network.HTTP.Simple`） | `http-conduit`パッケージ |
| `Servant.API.Experimental.Auth`・`Servant.Server.Experimental.Auth` | `servant`パッケージを直接`build-depends`に追加（`servant-server`だけでは`Servant.API.*`の個別モジュールは公開されない） |

`cabal build`・`cabal test`で「Could not load module」のようなエラーが
出た場合は、上記のいずれかが`.cabal`の`build-depends`に不足している
可能性が高い。
