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

## devcontainerの実際のマウント先が判明した（2026-08-09）

ユーザーが実際にDev Containerをrebuildし、上記の統合を検証・調整の上
コミットした（`9bfe121 iteration 2を実装`・`268d03a claudeの設定が
コミットされないよう変更`）。この調整により判明した実際の構成：

- `docker-compose.yml`は`.devcontainer/docker-compose.yml`に配置されて
  いる（リポジトリルートではない）。
- devcontainer.jsonの`workspaceFolder`は`/workspaces/haskell-saas-handson`
  ではなく`/workspaces`（リポジトリ内容が`/workspaces`直下に展開される。
  `saas-handson/`・`saas-handson-solution/`等はその直下）。
  `docker-compose.yml`の`app`サービスの`volumes`は`..:/workspaces:cached`、
  `build.context`は`..`（`.devcontainer/`から見た相対パス）になっている。
- `.gitignore`に`.devcontainer/claude-home/`・`.claude`が追加され、
  Claude Code自身の設定がリポジトリにコミットされないようになった。
- 以降のセッションでは`/workspaces/saas-handson`・
  `/workspaces/saas-handson-solution`のようにリポジトリ直下パスを使う
  （`/workspaces/haskell-saas-handson/...`ではない）。
- `mock-auth:8080`というサービス名解決は変わらず有効（`app`・
  `mock-auth`が同じdocker composeネットワーク上にあることは維持）。

## Iteration 3を実装した（2026-08-09）

ユーザー指示「続きのセクションも作成していって」を受け、Auto Mode下で
ROADMAPのIteration 3（マルチテナント対応）を、Iteration 2と同じ方針
（docs＋実コード両方、演習側TODOスタブ＋RED、解答例側フル実装＋GREEN）
で実装した。

### 設計判断

- テナントIDはJWTの`tenant_id`という非標準クレームとして受け取る
  設計にした。認証サーバー（mock-oauth2-server）がテナント所属を検証
  した上でクレーム発行する、という責務分担を前提にしている
  （`saas-handson-solution/docs/iteration-3.md`の「設計判断」節、および
  演習3-6の解説で、これがモックだから許容される簡略化であり本番の
  IdPでは任意のtenant_idをクライアントが指定できてはならない点を
  明記した）。
- `Crypto.JWT`の`ClaimsSet`は登録済みクレーム専用のため、`tenant_id`を
  扱うために`ClaimsSet`をラップした`TenantClaims`サブタイプ
  （`HasClaimsSet`・`FromJSON`インスタンスを実装）を`Auth.Server`に
  追加し、`verifyClaims`ではなく汎用の`verifyJWT`を使うよう変更した。
- `AuthenticatedUser`に`authTenantId :: TenantId`を追加。
  `User.Server`の`Store`を`IORef (Int, [User])`から
  `IORef (Map TenantId (Int, [User]))`に変更し、
  `createUserHandler`・`listUsersHandler`が`authTenantId authUser`を
  キーにしてMapをスコープするようにした（`containers`パッケージを両
  `.cabal`に追加）。
- `User.Api`・root`Api.hs`／`Server.hs`／`Main.hs`・`docker-compose.yml`
  は変更不要だった（Iteration 2で確立した`AuthenticatedUser`経由の
  仕組みに情報を1つ足すだけで済んだ）。
- mock-oauth2-serverの`claims`リクエストパラメータ（JSON文字列を
  トークンのクレームにマージする機能）を使い、docker-compose側の設定
  変更なしにテナントID違いのトークンを発行できることを演習3-2・3-6の
  curl手順として記載した。

### saas-handson-solution（解答例）側

- 上記をすべて実装し、`cabal test saas-handson-solution`で単体11件・
  結合8件、計19件GREENを確認済み（追加5テスト：AuthSpecに
  「tenant_idクレームがないトークンは拒否される」、UserSpec単体に
  テナント分離2件、UserSpec結合にテナント分離1件、既存テストの
  AuthenticatedUser構築にtenantId追加）。
- `test/unit/Auth/AuthSpec.hs`・`test/integration/User/UserSpec.hs`の
  トークン署名は`Crypto.JWT.addClaim`（非推奨API、コンパイル時に
  `-Wdeprecations`警告が出るが動作に問題はない）でtenant_idクレームを
  付与している。本番コード（`Auth.Server`）側は非推奨APIを使わず
  `TenantClaims`サブタイプ経由の推奨パターンを採用している、という
  非対称性を意図的に許容した（テストコードの簡潔さを優先）。
- `docs/iteration-3.md`を演習側の3-1〜3-6に1対1対応する解説として新規
  作成。

### saas-handson（演習用）側

- `src/Auth/Types.hs`（`TenantId`・`AuthenticatedUser`拡張、完成済み）・
  `src/Auth/Server.hs`（`TenantClaims`型・インスタンスは完成済み、
  `verify`本体はTODOのまま。コメントを「TODO: Iteration 2/3で実装する」
  に更新し、tenant_id抽出のヒントを追記）・`src/User/Server.hs`
  （`Store`の型・`newStore`は完成済み、`createUserHandler`・
  `listUsersHandler`本体はTODOのまま。コメントを
  「TODO: Iteration 1/3で実装する」に更新）を更新。
- テストファイル（`test/unit/Auth/AuthSpec.hs`・
  `test/unit/User/UserSpec.hs`・`test/integration/User/UserSpec.hs`）は
  解答例側と同一内容をそのまま反映（テストはお手本を書き写すものでは
  なく最初からGREENを目指す対象なので、演習側でも完全な形で用意する
  というIteration 1/2からの方針を踏襲）。
- `cabal build saas-handson`（lib・exe・test）はGREENを確認済み。
  `cabal test saas-handson`は意図通りREDで、単体11件中11件・結合8件中
  7件が`error "TODO: ..."`起因で失敗（「Authorizationヘッダなし→401」
  の1件のみ引き続きGREEN）。
- `docs/iteration-3.md`を演習3-1（型・仕組みを読み解く）〜3-6（発展：
  実サーバー疎通確認・IdPの本番運用における注意点・Iteration 4への
  接続）の6節構成で新規作成。

### 制約・未検証事項

- mock-oauth2-serverの`claims`リクエストパラメータ（`-d
  'claims={"tenant_id":"acme"}'`でJWTに任意のクレームをマージできる
  機能）は、Iteration 2のときと同様この開発環境にdockerコマンドが
  存在せず実機検証できていない。ドキュメント記載の既知の仕様に基づいて
  記述した。Haskell側のテナント分離ロジック自体はdockerに依存しない
  テスト（19件）で動作確認済み。

## Iteration 4を実装した（2026-08-09）

ユーザー指示「続きをやって」を受け、Auto Mode下でROADMAPのIteration 4
（永続化層の導入）を、Iteration 2・3と同じ方針（docs＋実コード両方、
演習側TODOスタブ＋RED、解答例側フル実装＋GREEN）で実装した。

### 設計判断

- ROADMAPは「sqlite-simpleまたはpostgresql-simple」を選択肢としていた
  が、**sqlite-simple**を選んだ。理由はIteration 2・3を通じて維持して
  きた「`cabal test`は外部プロセスに依存しない」方針を崩したくなかった
  ため。SQLiteは`":memory:"`接続でテストも本物のSQLを使いつつ完全に
  hermeticにできる（postgresql-simpleだとDBコンテナが必要になり、
  テストがdocker-compose起動状態に依存してしまう）。
- Repository抽象化は型クラスではなくレコード・オブ・関数
  （Handleパターン）で表現した
  （`data UserRepository = UserRepository { createUser :: ..., listUsers
  :: ... }`）。理由は`saas-handson-solution/docs/iteration-4.md`の
  「設計判断」節に詳述（実行時に実装を選ぶだけでよく型レベルの多態性が
  不要、内部状態をクロージャに閉じ込められる、Iteration 2の`JWKStore`
  と同じモチーフの再利用）。
- `User.Repository.InMemory`（Iteration 1・3のロジックをそのまま移設）
  と`User.Repository.Sqlite`（新規）の2実装を用意。SQLite側の採番は
  「テナントごとのMAX(id)+1」方式とし、`withImmediateTransaction`で
  読み取りより先に書き込みロックを取ることで競合状態を防いだ
  （`atomicModifyIORef'`のSQL版に相当する設計として説明）。
  `Connection`は`MVar`でラップしwithMVarで直列化した（sqlite-simpleの
  Connectionはマルチスレッドから同時アクセスされることを想定していない
  ため）。
- 両実装が同じ振る舞いをすることを保証するため、
  `test/unit/User/RepositorySpec.hs`に契約テスト
  （`repositoryContractSpec :: IO UserRepository -> Spec`を
  `newInMemoryUserRepository`・`newSqliteUserRepository ":memory:"`の
  両方に対して実行）を新設。結合テスト
  （`test/integration/User/UserSpec.hs`）もSQLite（`:memory:`）を使う
  ように変更し、HTTP層を含むend-to-endで本物のSQLを検証するように
  した。
- `User.Server`は`Store`・`newStore`のエクスポートをやめ、
  `UserRepository`を受け取って`createUser`/`listUsers`に委譲するだけの
  薄い層になった。root`Server.hs`・`Main.hs`も`Store`→`UserRepository`
  に置き換え。`app/Main.hs`は`newSqliteUserRepository
  "saas-handson(-solution).sqlite3"`でファイルDBを使う（`.gitignore`に
  `*.sqlite3`等を追加）。

### saas-handson-solution（解答例）側

- 上記をすべて実装し、`cabal test saas-handson-solution`で単体23件
  （Auth 5・Health 1・RepositorySpec 12〈in-memory 6＋SQLite 6〉・
  UserSpec 5）・結合8件、計31件GREENを確認済み。
- `docs/iteration-4.md`を演習側の4-1〜4-5に1対1対応する解説として新規
  作成。

### saas-handson（演習用）側

- `src/User/Repository.hs`（`UserRepository`型、完成済み）・
  `src/User/Repository/InMemory.hs`（構造は完成済み、
  `createUserImpl`・`listUsersImpl`はTODO。Iteration 1/3の未実装ロジック
  がここに移設された形）・`src/User/Repository/Sqlite.hs`（スキーマ
  作成・`FromRow`インスタンス・`MVar`配線は完成済み、
  `createUserImpl`・`listUsersImpl`のSQL本体はTODO）を新規追加。
  `src/User/Server.hs`はStore/TODOを撤去し、UserRepositoryへの委譲のみ
  の完成済みコードに置き換えた（ロジックがRepository側に移ったため）。
  root`src/Server.hs`・`app/Main.hs`もUserRepositoryを使う形に配線済み。
- テストファイルは解答例側と同一内容をそのまま反映（`RepositorySpec`
  新設、`UserSpec`単体・結合、`HealthSpec`単体・結合の`mkApp`/`mkServer`
  呼び出し元をすべて`UserRepository`ベースに更新）。
- `cabal build saas-handson`（lib・exe・test）はGREENを確認済み。
  `cabal test saas-handson`は意図通りREDで、単体23件中23件・結合8件中
  7件が`error "TODO: ..."`起因で失敗（「Authorizationヘッダなし→401」
  の1件のみ引き続きGREEN）。
- `docs/iteration-4.md`を演習4-1（Repository抽象化を読み解く）〜4-5
  （発展：永続化の実機確認・採番方式のトレードオフ・Handleパターンの
  一般化）の5節構成で新規作成。

### 制約・未検証事項

- 演習4-5の「サーバーを再起動してもデータが残ることを確認する」は、
  実際に`cabal run`でサーバーを起動・再起動する手順が必要なため、この
  環境では対話的に確認していない（`cabal build`が通ること、
  `newSqliteUserRepository`が単体・結合テストでファイルDB同等の
  `":memory:"`接続に対して正しく動くことは確認済み）。

## Iteration 4をSQLiteからPostgreSQL＋DI方針に作り直した（2026-08-09）

ユーザー指示を受け、Iteration 4を全面的に作り直した。指示内容：
(1) DBはPostgreSQLにする、(2) 単体テストはin-memoryを死守し実DBに
依存させない、(3) 結合テストは外部コンテナ（実DB）に依存してよい、
(4) OOPで言うDIのテクニックでテスタブルな状態を担保する、という設計
思想を明示的に教える、(5) 自動発番の責務をDB側に寄せる。

### 設計変更点

- `docker-compose.yml`（`.devcontainer/docker-compose.yml`）に`db`
  サービス（`postgres:16`、`app`・`mock-auth`と同じ`handson-net`）を
  追加。ホスト公開ポートは5433（コンテナ内は5432）。
- `.devcontainer/Dockerfile`に`libpq-dev`を追加（`postgresql-libpq`の
  ビルドに必要。追加前は`configure: error: Library requirements
  (PostgreSQL) not met`でビルド自体が失敗することをこのセッションで
  実際に確認し、追加後に解消したことも確認済み）。
- `User.Repository.Sqlite`を削除し`User.Repository.Postgres`に置き換え。
  採番はSQLiteの`SELECT MAX(id)+1`＋`withImmediateTransaction`方式から、
  PostgreSQLの`SERIAL`＋`INSERT ... RETURNING id`に変更。これに伴い
  アプリケーション側の明示的なトランザクション・ロック制御コードが
  丸ごと不要になった（`docs/iteration-4.md`で「自動発番の責務をDB側に
  寄せる」ことの具体例として詳説）。
- コネクション管理は`MVar Connection`（単一コネクションの直列化）から
  `resource-pool`の`Pool Connection`に変更（PostgreSQLは複数コネクション
  からの同時アクセスを安全に処理できるため）。
- idの採番方式を「テナントごとに1から連番」から「テナントを跨いだ
  グローバルな連番」に変更（PostgreSQLの`SERIAL`が単一テーブルに単一の
  連番しか払い出せないことに合わせた）。in-memory実装も同じ挙動に変更し、
  影響を受けた既存テスト（「テナントごとにid採番が独立している」）を
  「採番はテナントを跨いでグローバルに行われる」に書き換えた。
- **テスト層を明確に分離**：`test/unit`はUser.Repository.InMemoryのみ
  使用し実DBに一切依存しない。実DB（PostgreSQL）を使うテスト
  （契約テスト・HTTP結合テスト）はすべて`test/integration`に配置し、
  dbサービスへの依存を許容する。`test/integration/User/RepositorySpec.hs`
  を新設し、`test/unit`側と同じ`repositoryContractSpec`をPostgreSQLに
  対して実行する（TRUNCATE TABLE ... RESTART IDENTITYでテストごとに
  状態をリセット）。
- `docs/iteration-4.md`（両側）に、Repository抽象化＝OOPのDIに相当する
  という説明を明示的に追加（インターフェース＝`UserRepository`型、
  実装＝`newInMemoryUserRepository`/`newPostgresUserRepository`、
  注入＝`server repo`という普通の関数適用、コンポジションルート＝
  `main`関数・テストの`spec`関数）。

### 検証状況

- `saas-handson-solution`：ライブラリ・実行ファイルのビルド、単体テスト
  （17件、in-memoryのみ）は完全GREENを確認済み。結合テストは
  `libpq: failed (could not translate host name "db" to address ...)`
  というエラーで失敗するが、これはこの環境にdbコンテナ（Postgres）が
  実際に起動していないためであり、コンパイルは通ること・エラー内容が
  「DB未接続」であることまで確認済み（コードのロジック自体は単体テスト
  側の契約テストで間接的に検証されている、というのがこの教材の設計）。
- `saas-handson`：ライブラリ・実行ファイルのビルドはGREEN、単体テスト
  17件は意図通り全滅（TODO由来）、結合テストはコンパイルのみ確認。

### 制約・未検証事項

- 実際にdocker composeで`db`サービスを起動し、結合テスト
  （`test/integration/User/RepositorySpec.hs`・
  `test/integration/User/UserSpec.hs`）が実際にGREENになることは、
  この環境にdockerがないため確認できていない。次回Docker環境で
  `docker compose up -d`（またはdevcontainerを開く）→
  `cabal test saas-handson-solution:test:integration`を実行して確認
  する必要がある。

## 次にやること（案）

- 上記のPostgreSQL結合テストをDocker環境で実際に検証する。
- Iteration 5（権限管理・エラー設計）以降のdocsはまだ作成していない。
- 演習1-6・0-5・2-5・2-6・3-6・4-5のような発展課題について、必要で
  あれば模範解答をsaas-handson-solution側に別途用意するかどうかを検討
  する（現状は解説文のみで、コードとしては用意していない）。
