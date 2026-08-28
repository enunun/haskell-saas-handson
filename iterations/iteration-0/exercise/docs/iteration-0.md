# Iteration 0：演習

## この章で作るもの

`GET /health`エンドポイントを実装する。サーバーが正常に起動しリクエストを
処理できる状態にあるかを外部から確認するための、最小のヘルスチェックAPIで
ある。ドメインロジックを持たないシンプルなエンドポイントであるため、
Servantプロジェクトの雛形（型レベルAPI・ハンドラ・テスト環境）を確立する
題材として最初に扱う。

この教材はIterationを重ねるごとに、認証・マルチテナント対応・永続化層・
構造化ロギングへと機能を広げていく。Iteration 0はその出発点であり、
以降のIterationはそれぞれ独立したプロジェクトとして用意されている。

## 進め方

演習は0-1から順に、下位（型・ライブラリの理解）から上位（テスト・実装・
拡張）へと積み上げる構成になっている。各演習は前の演習を土台にするため、
順番を飛ばさないこと。詰まった場合は`../solution/docs/iteration-0.md`の
対応する節を読む。コマンドはリポジトリルート（`cabal.project`のある
場所）から実行する。

## 演習0-1：型を読み解く

`src/Types.hs`と`src/Api.hs`を読み、以下を自分の言葉で説明できるように
する（コードを書く必要はない）。

1. `HealthResponse`は`deriving (Generic)`されているのに、
   `instance ToJSON HealthResponse`・`instance FromJSON HealthResponse`の
   中身は空である。仮にこの2行を削除するとどうなるか。
2. `type API = "health" :> Get '[JSON] HealthResponse`という1行だけから、
   どのHTTPメソッド・パス・レスポンスの内容形式のエンドポイントが定義
   されているか読み取る。
3. `api :: Proxy API`の`Proxy`は何のために必要か。`API`という型そのものを
   値として直接扱えない理由を考える。

## 演習0-2：テストを自分で書く（Red）

`src/Server.hs`の`healthHandler`はまだ`error "TODO: ..."`のままである。
実装より先に、これから満たすべき仕様をテストとして書く。

1. `test/unit/HealthSpec.hs`を新規作成し、以下を検証する単体テストを書く。
   - `Server.mkServer`が返す`Handler HealthResponse`（`servant-server`の
     `runHandler`で実行する）の結果が`Right (HealthResponse "ok")`に
     等しいこと。
2. `test/integration/HealthSpec.hs`を新規作成し、以下を検証する結合テストを
   書く（`hspec-wai`を使う）。
   - `GET /health`がステータスコード200を返すこと。
   - レスポンスボディが`{"status":"ok"}`であること（`hspec-wai-json`の
     `[json|...|]`クオートが使える）。
   - `Server.mkApp :: Application`を`with`に渡す。
3. どちらのファイルも`module XxxSpec (spec) where`という形で`spec :: Spec`
   をエクスポートする（hspec-discoverが`*Spec.hs`を自動的に集約する）。
4. `saas-handson-iteration0.cabal`の`test-suite unit`・
   `test-suite integration`それぞれに`other-modules: HealthSpec`を追記する
   （cabalは`hs-source-dirs`配下のモジュールでも、コンパイル対象として
   明示的に列挙する必要がある）。

```sh
cabal test saas-handson-iteration0
```

を実行し、単体テスト・結合テストが両方失敗する（RED）ことを確認する。
それぞれの失敗メッセージを読み、`src/Server.hs`のどの行が原因になって
いるかを特定する。

## 演習0-3：healthHandlerを実装する（Green）

`src/Server.hs`の`healthHandler`を実装し、`cabal test
saas-handson-iteration0`で単体テスト・結合テストの両方をGREENにする。

- `HealthResponse`の`status`フィールドに`"ok"`を設定した値を返す。
- `healthHandler`の型は`Handler HealthResponse`である。`Handler`モナドの
  中で純粋な値をそのまま返すために、どの関数を使えばよいか調べる。

## 演習0-4：単体テストと結合テストを比較する

演習0-2で自分が書いた`test/unit/HealthSpec.hs`と
`test/integration/HealthSpec.hs`を読み比べ、以下に答える。

1. 単体テストは`runHandler`を、結合テストは`hspec-wai`の`get`を使って
   いる。それぞれのテストはどの層（ルーティング・JSONエンコード・
   ネットワーク）を経由し、どの層を経由しないか。
2. 現時点でこの2つのテストはほぼ同じ内容を検証している。なぜそう
   言えるか。
3. 今後ハンドラがバリデーションやドメインロジックの分岐を持つように
   なったとき、この2つのテストの役割はどのように分かれていくと予想
   するか（後続のIterationで答え合わせをする）。

## 演習0-5（発展）：レスポンスを拡張する

`HealthResponse`に新しいフィールド（例：アプリケーションのバージョンを
表す`version :: Text`）を1つ追加し、`GET /health`のレスポンスに含める。

1. まずテストを修正・追加してREDにする。
2. 型・実装を変更してGREENにする。
3. 命名や実装を見直し、テストがGREENのままリファクタリングする。

演習0-2〜0-3で経験したRed→Green→Refactorのサイクルを、今度は指示に
頼らず自力で再現することが目標である。仕上げに`cabal run
saas-handson-iteration0`でサーバーを起動し、`curl
http://localhost:8080/health`で実際のレスポンスを確認する。
