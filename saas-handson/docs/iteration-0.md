# Iteration 0：演習

## この章で作るもの

`GET /health`エンドポイントを実装する。サーバーが正常に起動しリクエストを
処理できる状態にあるかを外部から確認するための、最小のヘルスチェックAPIで
ある。ドメインロジックを持たないシンプルなエンドポイントであるため、
Servantプロジェクトの雛形（型レベルAPI・ハンドラ・テスト環境）を確立する
題材として最初に扱う。

## 進め方

演習は0-1から順に、下位（型・ライブラリの理解）から上位（実装・テスト・
拡張）へと積み上げる構成になっている。各演習は前の演習を土台にするため、
順番を飛ばさないこと。詰まった場合は`saas-handson-solution/docs/iteration-0.md`
の対応する節を読む。コマンドはリポジトリルート（`cabal.project`のある
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

## 演習0-2：Redを確認する

```sh
cabal test saas-handson
```

を実行し、単体テスト（`test/unit/HealthSpec.hs`）・結合テスト
（`test/integration/HealthSpec.hs`）が両方失敗する（RED）ことを確認する。
それぞれの失敗メッセージを読み、`src/Server.hs`のどの行が原因になって
いるかを特定する。

## 演習0-3：healthHandlerを実装する（Green）

`src/Server.hs`の`healthHandler`を実装し、`cabal test saas-handson`で
単体テスト・結合テストの両方をGREENにする。

- `HealthResponse`の`status`フィールドに`"ok"`を設定した値を返す。
- `healthHandler`の型は`Handler HealthResponse`である。`Handler`モナドの
  中で純粋な値をそのまま返すために、どの関数を使えばよいか調べる。

## 演習0-4：単体テストと結合テストを比較する

`test/unit/HealthSpec.hs`と`test/integration/HealthSpec.hs`を読み比べ、
以下に答える。

1. 単体テストは`runHandler`を、結合テストは`hspec-wai`の`get`を使って
   いる。それぞれのテストはどの層（ルーティング・JSONエンコード・
   ネットワーク）を経由し、どの層を経由しないか。
2. 現時点でこの2つのテストはほぼ同じ内容を検証している。なぜそう
   言えるか。
3. 今後ハンドラがバリデーションやドメインロジックの分岐を持つように
   なったとき、この2つのテストの役割はどのように分かれていくと予想
   するか（Iteration 1で答え合わせをする）。

## 演習0-5（発展）：レスポンスを拡張する

`HealthResponse`に新しいフィールド（例：アプリケーションのバージョンを
表す`version :: Text`）を1つ追加し、`GET /health`のレスポンスに含める。

1. まずテストを修正・追加してREDにする。
2. 型・実装を変更してGREENにする。
3. 命名や実装を見直し、テストがGREENのままリファクタリングする。

演習0-2〜0-3で経験したRed→Green→Refactorのサイクルを、今度は指示に
頼らず自力で再現することが目標である。仕上げに`cabal run saas-handson`
でサーバーを起動し、`curl http://localhost:8080/health`で実際のレスポンス
を確認する。
