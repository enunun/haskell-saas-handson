# Iteration 0：解説

## 実装する機能

ヘルスチェックAPI（`GET /health`）を実装する。サーバーが正常に起動し、
リクエストを処理できる状態にあるかを外部から確認するためのエンドポイント
である。

toBのSaaSでは、以下のような場面でヘルスチェックAPIが利用される。

- ロードバランサが、リクエストを振り分けてよいインスタンスかどうかを
  判定する
- KubernetesなどのオーケストレータがliveenessProbe／readinessProbeとして
  定期的に呼び出し、異常なインスタンスを自動的に切り離す
- デプロイ後の起動確認や、外形監視サービスによる死活監視

ドメインロジックを持たない最小のエンドポイントであるため、業務要件を
考える前にプロジェクトの雛形（ビルド構成・ルーティング・テスト環境）を
確立する題材として、最初のイテレーションに選んでいる。

## 目的

`GET /health`を題材に、Servantプロジェクトの最小構成とTDDサイクルを確立する。

## 設計パターン

### 型レベルAPI設計（Type-Level API）

Servantでは、エンドポイントの仕様を値ではなく型で表現する。`API`型は次の
ように定義される。

```haskell
type API = "health" :> Get '[JSON] HealthResponse
```

この型はパス・HTTPメソッド・レスポンスの内容形式・ボディの型をすべて含む。
実装（`server`）はこの型から導出される型を満たす必要があり、満たさなければ
コンパイルが通らない。仕様と実装の乖離をコンパイル時に検出できる点が、
実行時にルーティング定義を検証する多くのWebフレームワークとの違いである。

### 仕様と実装の分離

`Api.hs`（型）と`Server.hs`（実装）を別モジュールに分離している。これは
インターフェースと実装を分けるという一般的な設計原則をServantの型システム
上で自然に体現したものである。イテレーションが進み複数のリソースを扱う
段階になっても、この分離を保つ。

### Proxyパターン

```haskell
api :: Proxy API
api = Proxy
```

`API`は型であり値ではないため、実行時に型情報を関数へ渡す手段として
`Data.Proxy`の`Proxy`を用いる。これは型レベル情報を値レベルへ橋渡しする
Haskellの定型的な手法であり、Servant以外のライブラリでも頻出する。

### WAI Applicationによる抽象化

```haskell
app :: Application
app = serve api server
```

`serve`はAPI型とハンドラから`Network.Wai.Application`を生成する。WAIは
Haskellにおける標準的なWebサーバーインターフェースであり、`app`自体は
特定のサーバー実装（warp）に依存しない。サーバーの起動処理（`Main.hs`）と
アプリケーションロジック（`Server.hs`）が分離されることで、テスト時に
サーバーを起動せずアプリケーションを直接検証できる。

## 使用ライブラリ

| ライブラリ | 役割 |
|---|---|
| servant-server | 型レベルAPI定義からWAI Applicationを生成する |
| warp | WAI Applicationを実行するHTTPサーバー |
| aeson | JSONのエンコード・デコード |
| hspec | テストフレームワーク本体 |
| hspec-wai | WAI Applicationに対しHTTPリクエストを直接発行してテストする |

### aesonとGHC.Genericsの組み合わせ

```haskell
newtype HealthResponse = HealthResponse { status :: Text }
  deriving (Show, Eq, Generic)

instance ToJSON HealthResponse
instance FromJSON HealthResponse
```

`deriving Generic`によりレコードの構造がコンパイラに認識され、`aeson`は
そこからJSONへの変換規則を自動導出する。フィールド名がそのままJSONキーと
なるため、手動でのエンコーダ実装が不要になる。この方式はaesonにおける
標準的な定型パターンである。

### hspec-wai：Applicationを直接テストする

```haskell
spec = with (pure app) $
  describe "GET /health" $ do
    it "ステータスコード200を返す" $
      get "/health" `shouldRespondWith` 200
```

hspec-waiは実際にHTTPサーバーを起動することなく、WAI Application相手に
リクエストを発行して結果を検証する。ネットワークやポートに依存しないため
テストが高速かつ決定的になる。

## TDDサイクル

1. `test/unit/HealthSpec.hs`と`test/integration/HealthSpec.hs`を先に用意し、
   `cabal test`を実行してどちらもREDであることを確認する。
2. `src/Server.hs`のハンドラを実装し、両方GREENにする。
3. 型シグネチャや命名を見直し、テストがGREENのままリファクタリングする。

このサイクルをイテレーション単位で繰り返すことが本教材の基本方針である。

## テスト戦略：単体テストと結合テストの区別

本教材では`test/unit`と`test/integration`をcabalの別々のtest-suiteとして
分離している。

| 種別 | ディレクトリ | 検証対象 | 経由する層 |
|---|---|---|---|
| 単体テスト | `test/unit` | ハンドラの戻り値そのもの | なし（`runHandler`でHandlerモナドを直接実行） |
| 結合テスト | `test/integration` | HTTPリクエストに対する応答全体 | ルーティング・JSONエンコード・WAI Application |

単体テストは`servant-server`の`runHandler`を使い、`Handler`モナドの計算
結果をHTTP層を経由せず直接取り出す。結合テストは`hspec-wai`を使い、
`serve`が生成したWAI Application相手に実際のHTTPリクエストに近い形で
検証する。

`GET /health`はレスポンスが固定値であり分岐を持たないため、現時点では
両者の内容がほぼ一致しており、区別する意味が薄く見える。それでも最初の
イテレーションからディレクトリとtest-suiteを分けておくのは、Iteration 1
以降でハンドラがバリデーションやドメインロジックを持ち始めた際に、

- 単体テスト：ロジックの分岐やエッジケースを、Web層を起動せず高速に
  大量に検証する
- 結合テスト：ルーティング定義やJSONのフィールド名といった、実際に
  HTTP越しでなければ検出できない不整合を検証する

という役割分担を自然に維持するためである。テストの追加先に迷わないよう、
ディレクトリ構成を先に決めておく。

