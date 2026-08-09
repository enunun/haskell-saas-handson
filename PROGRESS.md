# 作業ログ・進捗

## これまでにやったこと（2026-08-09）

`docs/iteration-0.md`・`docs/iteration-1.md`が、演習用（`saas-handson`）・
解答例（`saas-handson-solution`）の両方で内容が同一の「設計解説」でしか
なく、単なる作業ログのようになっていた課題を解消した。演習と解答を
明確に分離し、ボトムアップ・ステップアップ式の演習問題形式に書き直した。

### saas-handson（演習用）側

- `docs/iteration-0.md`：演習0-1〜0-5。型を読む（コードなし理解問題）→
  Redを確認する→`healthHandler`を実装する（Green）→単体/結合テストを
  比較する→レスポンスを拡張する（発展）、という順。
- `docs/iteration-1.md`：演習1-1〜1-6。`User`/`CreateUserRequest`の型を
  読む→`listUsersHandler`（読み取りのみ、単純）を実装する→
  `createUserHandler`（`atomicModifyIORef'`、書き込み）を実装する→
  テスト全体をGREENにする→Healthを機能別構成へリファクタリングする→
  疎通確認と設計の一般化（発展）、という順。
- コードそのものの答えは書かず、課題・確認方法・考えるためのヒントの
  みを記載する形式にした。

### saas-handson-solution（解答例）側

- `docs/iteration-0.md`・`docs/iteration-1.md`を、演習側の番号
  （0-1〜0-5、1-1〜1-6）に1対1で対応する解説として再構成した。
- 元々あった設計パターン解説（Proxyパターン、型レベルAPI設計、`:<|>`
  によるAPI合成、`ReqBody`、`PostCreated`、`IORef`と
  `atomicModifyIORef'`、テスト戦略など）はそのまま活かしつつ、演習側で
  出した理解確認の設問（例：「フィールド名をなぜずらしているか」）への
  回答も明記した。

### その他

- 和欧文スペース（日本語と半角英数字の間に空白を入れない）のルールを
  4ファイルすべてに適用し、機械的にチェック済み（該当なし）。
- `saas-handson`側の`src/Server.hs`・`src/User/Server.hs`のTODOや
  `README.md`・`docs/ROADMAP.md`のコード・記述自体は今回変更していない
  （docsの構成のみ変更）。テストは引き続きRED（意図通り、学習者が
  演習を通してGREENにする）。

## Iteration 2を実装した（2026-08-09）

Iteration 2（認証）について、docsだけでなく実コードも新規に実装した
（ユーザー指示：認証方式は外部サービスに委譲する構成、実コード・docsの
両方を用意する）。

### 設計判断

- 認証サーバー自体はローカル開発用にdocker-compose起動する
  mock-oauth2-server（Navikt製、`ghcr.io/navikt/mock-oauth2-server`）を
  採用。自前でのログイン・パスワード管理は実装せず、アプリ側はJWTの
  検証のみを行う構成とした（`docker-compose.yml`はリポジトリルート）。
- Servantの汎用認証コンビネータ`AuthProtect "jwt"`を`User.Api`の両
  エンドポイントに追加し、`AuthServerData`型族で`AuthenticatedUser`
  （`sub`クレームを保持）と結び付けた。`Health.Api`には付けず、
  ヘルスチェックは引き続き認証なしでアクセスできるようにした。
- JWT検証は`jose`パッケージ（`Crypto.JWT`）を使用。署名検証は
  `Crypto.JOSE.JWK.Store`の`VerificationKeyStore JWKSet`インスタンスに
  任せ、JWKSet全体を鍵ストアとして渡す（`kid`による絞り込みはしない、
  1鍵構成前提の簡略化）。audience（`aud`）の検証も簡略化のため省略
  （`const True`）。
- 単体・結合テストはいずれもdocker-compose起動中のmock-oauth2-serverに
  依存しない。テストコード内で`Crypto.JOSE.genJWK`によりその場でRSA鍵を
  生成し、`signClaims`で署名したJWTを使って検証する
  （`saas-handson-solution`側`cabal test`は8+7件全てGREENを確認済み）。

### saas-handson（演習用）側

- `src/Auth/Types.hs`（完成済み、読み解き対象）・
  `src/Auth/Server.hs`（`verify`のみTODO、他は完成済みの足場）を新規
  追加。`src/User/Api.hs`にAuthProtectを追加し、`src/User/Server.hs`の
  ハンドラ型に`AuthenticatedUser`引数を追加（本体は引き続きIteration 1
  のTODOのまま）。`src/Server.hs`・`app/Main.hs`は`serveWithContext`・
  `JWKStore`を使う形にすでに配線済み（配線自体をTODOにすると
  `cabal build`自体が失敗してしまうため、Store配線と同様「与えられた
  足場」として提供する設計とした）。
- `cabal build saas-handson`（lib・exe・test両方）はGREENを確認済み。
  `cabal test saas-handson`は意図通りREDで、失敗内容はすべて
  `error "TODO: ..."`に起因する（Auth 4件、Health 2〜3件、User 5〜6件。
  「Authorizationヘッダなし→401」の1件のみ、認証チェックが
  ハンドラ本体より先に走るため既にGREEN）。
- `docs/iteration-2.md`を演習2-1（型・仕組みを読み解く）〜2-6（発展：
  audience検証・discoveryドキュメント対応・Iteration 3への接続）の
  6節構成で新規作成。

### saas-handson-solution（解答例）側

- 上記の設計をすべて実装し、`cabal test saas-handson-solution`で
  単体8件・結合7件、計15件GREENを確認済み。
- `docs/iteration-2.md`を演習側の2-1〜2-6に1対1対応する解説として新規
  作成。「なぜ外部サービスに認証を委譲したか」という設計判断の背景も
  明記した。

### 制約・未検証事項

- この開発環境にdockerコマンドが存在せず、`docker compose up -d`から
  実際にmock-oauth2-serverを起動してcurlで疎通確認する流れ
  （演習2-2・2-5相当）は実機検証できていない。mock-oauth2-serverの
  エンドポイント仕様（`/default/token`・`/default/jwks`・
  `client_credentials`グラントでの`sub`＝`client_id`という挙動）は
  ドキュメント記載の既知の仕様に基づいて記述した。Haskell側のJWT
  検証ロジック自体はdockerに依存しないテストで動作確認済みだが、
  docker-compose.yml・curl手順は次回docker環境で実際に手を動かして
  検証するとよい。

## devcontainerをdocker composeベースに統合した（2026-08-09）

初版の`docker-compose.yml`（mock-authサービスのみ）は、既存の
`.devcontainer/Dockerfile`（単体の`"build"`指定のdevcontainer.json）と
噛み合っていなかった（学習者が別途`docker compose up -d`を実行する前提
だったが、実際の想定はdevcontainerに入って検証する、というものだった）。
これを受けて、devcontainer自体をdocker composeベースに変更しマージした。

- `docker-compose.yml`に`app`サービス（`.devcontainer/Dockerfile`を
  ビルド、ワークスペースを`/workspaces/haskell-saas-handson`にマウント、
  `mock-auth`に`depends_on`）を追加。
- `.devcontainer/devcontainer.json`を`"build"`指定から
  `"dockerComposeFile"` + `"service": "app"`指定に変更
  （`workspaceFolder`は既存の自動マウント先と同じ
  `/workspaces/haskell-saas-handson`に明示的に合わせた。
  `mounts`・`postCreateCommand`等は変更なし）。
- `app/Main.hs`（両パッケージ）のJWKS URIを`http://localhost:8081/...`
  から、docker composeのサービス名解決を使う
  `http://mock-auth:8080/...`に変更。両コンテナは同じdocker compose
  ネットワーク上の別コンテナなので、コンテナ間通信はホスト公開ポート
  （8081）ではなくコンテナ内ポート（8080）＋サービス名で行う。
- 両`docs/iteration-2.md`のcurl手順を「devcontainerを開けばmock-authは
  既に起動している」「`mock-auth:8080`にアクセスする」という前提に
  書き換えた（`docker compose up -d`を利用者が別途叩く記述を削除）。

この変更はdockerを使ったdevcontainerのビルド・起動そのものを要する
ため、この開発環境（dockerコマンドなし）では検証できていない。次回、
実際にDockerが使える環境でVS CodeからDev Container "Rebuild"を実行し、
`app`・`mock-auth`の両コンテナが起動すること、コンテナ内から
`curl http://mock-auth:8080/default/jwks`が疎通することを確認する
必要がある。

## 次にやること（案）

- 上記のdevcontainer統合をDockerが使える環境で実際に検証する
  （Rebuild Container→`cabal build`→`curl http://mock-auth:8080/...`）。
- `docs/ROADMAP.md`のIteration 2の「状態」を演習側は「着手中」、解答例
  側は「完了」に更新済み。Iteration 3（マルチテナント対応）以降のdocsは
  まだ作成していない。今回確立した認証の型（`AuthenticatedUser`）を
  テナント識別にどう拡張するかがIteration 3の設計の起点になる
  （`saas-handson-solution/docs/iteration-2.md`の演習2-6解説を参照）。
- 演習1-6・0-5・2-5・2-6のような発展課題について、必要であれば模範解答
  をsaas-handson-solution側に別途用意するかどうかを検討する（現状は
  解説文のみで、コードとしては用意していない）。
