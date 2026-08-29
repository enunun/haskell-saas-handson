# Iteration 2：演習

## この章で作るもの

外部認証サーバー（mock-oauth2-server）が発行するJWTを検証し、
未認証のリクエストを拒否するようにする。`POST /users`・`GET /users`・
`GET /users/{id}`を保護し、`GET /health`は引き続き認証なしとする。

`src/Auth/Types.hs`・`src/Auth/Server.hs`はすでに完成している
（joseライブラリでのJWT検証は本教材の主題ではないため、既存の実装を
読んで理解する形にしている）。この章の演習は、この2つのモジュールを
Userの機能に配線することが中心になる。

## 進め方

演習は2-1から順に取り組む。詰まった場合は`../solution/docs/iteration-2.md`
の対応する節を読む。コマンドはリポジトリルート（`cabal.project`のある
場所）から実行する。

## 演習2-1：Auth層を読み解く

`src/Auth/Types.hs`・`src/Auth/Server.hs`を読み、以下を自分の言葉で
説明できるようにする（コードを書く必要はない）。

1. `type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser`
   という1行は何をしているか。この行がないと何が起こるか。
2. `verifyToken`が返す`IO (Either JWTError AuthenticatedUser)`のうち、
   `Left`になるケースを`verify`の実装から3つ以上挙げる。
3. `JWKStore`には`newJWKStore`（ネットワーク経由）と`mkJWKStore`
   （既知の`JWKSet`から直接）という2つの作り方がある。それぞれ
   どちらで使うのが適切か（本番運用時／テスト時）。
4. `authHandler`が`mkAuthHandler`に渡している`check`関数は、
   `Request -> Handler AuthenticatedUser`という型を持つ。Servantは
   このハンドラをどのタイミングで呼び出すと考えられるか（ルーティング
   より前か後か）。

## 演習2-2：User.ApiにAuthProtectを追加する

`src/User/Api.hs`の3つのエンドポイントすべてに`AuthProtect "jwt" :>`を
先頭に追加する。

```haskell
-- src/User/Api.hs
type API =
       AuthProtect "jwt" :> "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
  :<|> AuthProtect "jwt" :> "users" :> Get '[JSON] [User]
  :<|> AuthProtect "jwt" :> "users" :> Capture "id" Int :> Get '[JSON] User
```

`import Servant.API.Experimental.Auth (AuthProtect)`が必要になる。

## 演習2-3：ハンドラの型を合わせる（Red：コンパイルエラー）

`src/User/Server.hs`の3つのハンドラの型シグネチャに、
`AuthenticatedUser ->`を先頭に追加する（`import Auth.Types
(AuthenticatedUser)`が必要）。ハンドラ本体は`AuthenticatedUser`を
使わなくてよい（今回は認証を要求するだけで、「誰か」によって振る舞いを
変える機能はまだない）。

この時点で`cabal build saas-handson-iteration2`を実行すると、
`test/unit/User/UserSpec.hs`・`test/integration/User/UserSpec.hs`が
コンパイルエラーになる（ハンドラの引数の数・型が変わったため）。
これも一種のRedである。エラーメッセージを読み、どのテストのどの行が
古い呼び出し方のままかを特定する。

## 演習2-4：既存のテストを認証に対応させる

既存の`test/unit/User/UserSpec.hs`・`test/integration/User/UserSpec.hs`
を、認証ありの世界に合わせて書き換える。

1. 単体テストでは、`AuthenticatedUser "alice"`のような固定値を用意し、
   各ハンドラ呼び出しの最初の引数として渡すだけでよい（単体テストは
   `User.Server.server`を直接呼ぶため、JWTの検証自体は経由しない）。
2. 結合テストでは、実際にJWTを検証させる必要がある。テスト専用の
   RSA鍵ペアを`Crypto.JOSE`の`genJWK (RSAGenParam (2048 \`div\` 8))`で
   その場で生成し、`Crypto.JWT`の`emptyClaimsSet`・`claimSub`・
   `claimExp`・`signClaims`でトークンを組み立て、
   `Auth.Server.mkJWKStore (JWKSet [jwk])`で、同じ鍵を検証側にも
   注入する（外部のmock-authサーバーには一切接続しない）。
   `Servant.serveWithContext`と`Auth.Server.authContext`を使って
   Applicationを組み立てる。
3. 既存のリクエストに`("Authorization", "Bearer " <> token)`ヘッダを
   追加する。
4. 新しく、以下を検証するテストケースも追加する。
   - `Authorization`ヘッダがない場合、401が返る。
   - 不正な文字列（JWTとして解釈できない値）をトークンとして送ると、
     401が返る。

```sh
cabal test saas-handson-iteration2:test:unit saas-handson-iteration2:test:integration
```

を実行し、すべてGREENになることを確認する。

## 演習2-5：トップレベルの配線を直す

`src/Server.hs`の`mkApp`を、`serve`ではなく`serveWithContext`を使う形に
変更し、`Auth.Server.authContext`を渡す`JWKStore`を引数として受け取る
ようにする（`mkServer`はそのままでよい）。`app/Main.hs`で
`Auth.Server.newJWKStore "http://mock-auth:8080/default/jwks"`を呼んで
`JWKStore`を作り、`mkApp`に渡すように変更する。

```sh
cabal build saas-handson-iteration2
```

がビルドできることを確認する（`mock-auth`サービスへの接続はサーバー
起動時にのみ必要で、テストの実行には必要ない）。

## 演習2-6：単体テスト・結合テストへの影響を考える

1. 演習2-4で、単体テストと結合テストでは認証の扱い方が異なっていた
   （固定値を渡すだけ vs. 実際にトークンを署名・検証する）。なぜこの
   違いが生まれるか、それぞれのテストがどの層を経由するかから説明する。
2. `Health`機能のテストは、この演習を通して一切変更していない。なぜ
   Healthは影響を受けなかったのか。

## 演習2-7（発展）：疎通確認

`cabal run saas-handson-iteration2`でサーバーを起動し（devcontainerの
`mock-auth`サービスが起動している前提）、実際にトークンを取得して
リクエストを送る。

```sh
TOKEN=$(curl -s -X POST http://mock-auth:8080/default/token \
  -d grant_type=client_credentials -d client_id=alice -d client_secret=dummy \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

curl http://localhost:8080/users -H "Authorization: Bearer $TOKEN"
curl http://localhost:8080/users
```

トークンなしのリクエストが401になることを確認する。
