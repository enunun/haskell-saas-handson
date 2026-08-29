# Iteration 0：解説

このドキュメントは`../../exercise/docs/iteration-0.md`の演習問題に対応する
解答解説である。見出しの番号（0-1〜0-5）は演習側と対応している。

## 演習0-1の解説：型を読み解く

### 型レベルAPI設計（Type-Level API）

Servantでは、エンドポイントの仕様を値ではなく型で表現する。`API`型は
次のように定義される。

```haskell
-- src/Api.hs
type API = "health" :> Get '[JSON] HealthResponse
```

この型はパス（`"health"`）・HTTPメソッド（`Get`）・レスポンスの内容形式
（`'[JSON]`）・ボディの型（`HealthResponse`）をすべて含む。実装
（`server`）はこの型から導出される型を満たす必要があり、満たさなければ
コンパイルが通らない。仕様と実装の乖離をコンパイル時に検出できる点が、
実行時にルーティング定義を検証する多くのWebフレームワークとの違いで
ある。

### Proxyパターン

```haskell
-- src/Api.hs
api :: Proxy API
api = Proxy
```

`serve`は`HasServer api context => Proxy api -> Server api -> Application`
という型を持つ。`api`は型変数であり、`serve`がどの`HasServer`インス
タンスを使うかは、この`api`が何の型に決まるかで決まる。

Haskellの型変数は、関数に渡した引数の型と関数の型シグネチャを照合する
こと（unification）でしか決まらない。`API`という型そのものを引数として
直接渡す構文はないため、`api`を`API`に決めさせるには「型が`Proxy API`
である値」を渡す必要がある。`Proxy a`はコンストラクタが1つ
（`Proxy`）・フィールドが0個の型であり、実行時のデータを何も運ばない。
`api :: Proxy API`という値を`serve`に渡すと、引数の型`Proxy api`と
実際の値の型`Proxy API`が照合され、`api`が`API`に決まる。つまり
`Proxy`は、データを一切運ばずに型変数だけを確定させるための値である。

（`TypeApplications`という言語拡張を使えば`serve @API server`のように
型を直接指定でき、`Proxy`値を渡さずに同じことができる。`Proxy`は
その拡張が広まる前から使われてきた、値の型を介して型変数を確定させる
定型的な手法であり、Servant以外のライブラリでも頻出する。）

### aesonとGHC.Genericsの組み合わせ

```haskell
-- src/Types.hs
newtype HealthResponse = HealthResponse { status :: Text }
  deriving (Show, Eq, Generic)

instance ToJSON HealthResponse
instance FromJSON HealthResponse
```

`deriving (Generic)`はレコードの構造（フィールド名・型）をコンパイラに
認識させるだけであり、それ自体はJSONへの変換を提供しない。`ToJSON`・
`FromJSON`の変換規則は`aeson`が`Generic`の情報から導出するが、そのために
は`instance ToJSON HealthResponse`という宣言自体は必要である（中身は
`Generic`によるデフォルト実装に委ねられるため空でよい）。

演習0-1の問い1の答え：この2行を削除すると、`HealthResponse`に対する
`ToJSON`・`FromJSON`インスタンスが存在しないことになる。`serve`は
`Get '[JSON] HealthResponse`を満たすために`ToJSON HealthResponse`を要求
するため、`src/Server.hs`側でコンパイルエラーになる。フィールド名が
そのままJSONキーになるため手動でのエンコーダ実装は不要だが、
「インスタンスとして存在を宣言すること」自体は省略できない。

演習0-1の問い2の答え：パスは`/health`、HTTPメソッドはGET、レスポンスは
`Content-Type: application/json`で`HealthResponse`をエンコードしたボディ
を返す、というエンドポイントが定義されている。

演習0-1の問い3の答え：`serve`は`HasServer api context => Proxy api ->
Server api -> Application`という型を持ち、`api`は型変数である。関数の
型変数は、渡した引数の型と関数の型シグネチャを照合すること
（unification）でしか決まらない。`API`という型そのものを直接渡す手段は
ないため、`api`を`API`に決めさせるには「型が`Proxy API`であるような
値」を渡す必要がある。`Proxy`はコンストラクタが1つ・フィールドが0個の
型であり、実行時のデータを何も運ばない代わりに、型パラメータだけを
運ぶ。`api = Proxy :: Proxy API`という値を渡すことで、データなしに
`api ~ API`という型の等式だけを`serve`に伝えている。

## 演習0-2の解説：テストを自分で書く

### hspec-wai：Applicationを直接テストする

```haskell
-- test/integration/HealthSpec.hs
spec = with (pure mkApp) $
  describe "GET /health" $ do
    it "ステータスコード200を返す" $
      get "/health" `shouldRespondWith` 200
```

hspec-waiは実際にHTTPサーバーを起動することなく、WAI Application相手に
リクエストを発行して結果を検証する。ネットワークやポートに依存しない
ため、テストが高速かつ決定的になる。`with`には`IO Application`を渡す
（`mkApp`は`Application`そのものなので`pure`で包む）。

### hspec-wai-json：JSONレスポンスの検証

```haskell
-- test/integration/HealthSpec.hs
get "/health" `shouldRespondWith` [json|{status:"ok"}|]
```

`[json|...|]`は`hspec-wai-json`が提供するquasi quoterで、レスポンス
ボディをJSONとしてパースしてから期待値と比較する（文字列の完全一致では
なく、キーの順序に依存しない構造的な比較になる）。

### 単体テストの書き方

```haskell
-- test/unit/HealthSpec.hs
spec = describe "healthHandler（単体）" $
  it "statusフィールドにokを返す" $ do
    result <- runHandler mkServer
    result `shouldBe` Right (HealthResponse "ok")
```

`servant-server`の`runHandler`は`Handler a`の計算を実行し
`IO (Either ServerError a)`を返す。healthエンドポイントは引数を取らない
ため、`mkServer`自体が`Handler HealthResponse`である。

### TDDサイクル

1. まだ何も実装されていない状態で`test/unit/HealthSpec.hs`・
   `test/integration/HealthSpec.hs`を書き、RED（演習0-2）であることを
   確認する。
2. `src/Server.hs`のハンドラを実装し、両方GREENにする（演習0-3）。
3. 型シグネチャや命名を見直し、テストがGREENのままリファクタリングする
   （演習0-5で自力で体験する）。

このサイクルをイテレーション単位で繰り返すことが本教材の基本方針である。

## 演習0-3の解説：healthHandlerを実装する

```haskell
-- src/Server.hs
healthHandler :: Handler HealthResponse
healthHandler = pure (HealthResponse "ok")
```

`Handler`はServantが提供するハンドラ用のモナドであり、`IO`をベースに
した`ExceptT ServerError IO`相当の型である。副作用を伴わず値をそのまま
返すだけであれば`pure`（`return`と同義）で十分であり、`liftIO`のような
持ち上げは不要になる。

### 仕様と実装の分離

`Api.hs`（型）と`Server.hs`（実装）を別モジュールに分離している。これは
インターフェースと実装を分けるという一般的な設計原則を、Servantの型
システム上で自然に体現したものである。

### WAI Applicationによる抽象化

```haskell
-- src/Server.hs
mkApp :: Application
mkApp = serve api mkServer
```

`serve`はAPI型とハンドラから`Network.Wai.Application`を生成する。WAIは
Haskellにおける標準的なWebサーバーインターフェースであり、`mkApp`自体は
特定のサーバー実装（warp）に依存しない。サーバーの起動処理
（`app/Main.hs`）とアプリケーションロジック（`Server.hs`）が分離される
ことで、テスト時にサーバーを起動せずアプリケーションを直接検証できる。

## 演習0-4の解説：単体テストと結合テストを比較する

本教材では`test/unit`と`test/integration`をcabalの別々のtest-suiteとして
分離している。

| 種別 | ディレクトリ | 検証対象 | 経由する層 |
|---|---|---|---|
| 単体テスト | `test/unit` | ハンドラの戻り値そのもの | なし（`runHandler`でHandlerモナドを直接実行） |
| 結合テスト | `test/integration` | HTTPリクエストに対する応答全体 | ルーティング・JSONエンコード・WAI Application |

問い1の答え：単体テストは`runHandler`で`Handler`モナドの計算結果を直接
取り出すため、HTTPリクエストのパース・ルーティング・JSONエンコードと
いったWeb層を一切経由しない。結合テストは`serve`が生成したWAI
Applicationに対して実際にHTTPリクエストに近い形でアクセスするため、
これらすべての層を経由する。

問い2の答え：`GET /health`はレスポンスが固定値であり分岐を持たない
ため、Handlerモナドの計算結果（単体テスト）とHTTP応答全体（結合
テスト）がほぼ一致する。ルーティングやJSONエンコードの層を通しても
通さなくても、検証している内容の実質は変わらない。

問い3の答え：後続のIterationでハンドラがバリデーションや状態遷移
（採番・一覧の蓄積）を持ち始めると、単体テストはロジックの分岐やエッジ
ケースをWeb層なしで高速に検証する役割を、結合テストはルーティング定義や
JSONのフィールド名といった実際にHTTP越しでなければ検出できない不整合
を検証する役割を、それぞれ担うようになる。

## 演習0-5の解説（発展）：レスポンスを拡張する

新しいフィールドを追加する際の手順は以下のようになる。

1. 結合テストの期待値に新しいフィールドを追加し、REDになることを確認
   する（例：`get "/health" `shouldRespondWith` [json|{status:"ok",version:"0.1.0"}|]`）。
2. `src/Types.hs`の`HealthResponse`にフィールドを追加する。`deriving
   (Generic)`のままであれば、`ToJSON`/`FromJSON`側の手直しは不要で
   ある。
3. `src/Server.hs`の`healthHandler`が返す値を新しいフィールドに対応
   させ、GREENにする。

### 技術層別構成という選択（1機能のみの現段階）

`src/Api.hs`・`src/Server.hs`・`src/Types.hs`という分割は、「型定義」
「ハンドラ実装」「データ型」という技術的な層（レイヤー）ごとの分割で
ある。`GET /health`という1エンドポイントしか存在しない現段階では、
これは標準的かつ適切な選択である。

一方でこの分割のまま機能（Health, User, ...）が増えていくと、1つの
`Api.hs`にすべてのルート定義、1つの`Server.hs`にすべてのハンドラが
積み重なっていき、どのファイルを見ても機能ごとの境界が見えなくなる。
かといって、1機能しかない今の段階で先回りして機能別ディレクトリ
（`src/Health/{Api,Server,Types}.hs`のような構成）に分けても、分割の
恩恵はまだ出ず、単にディレクトリが1段深くなるだけである（境界の引き方
は2つ目の機能が来て初めて見えるものであり、それより前に決めるのは早
すぎる）。

そのため本教材では、Iteration 0はこの技術層別構成のままとし、2つ目の
機能（User）が加わる次のIterationの冒頭で、技術層別から機能別
（Vertical Slice）への構成変更を明示的なリファクタリングステップとして
行う（別プロジェクトのテーマである）。`version`フィールドの追加のような
「既存の1機能の中で完結する変更」は技術層別構成のままで問題なく行える
ことを、この演習で体感できる。

## 使用ライブラリ

| ライブラリ | 役割 |
|---|---|
| servant-server | 型レベルAPI定義からWAI Applicationを生成する |
| warp | WAI Applicationを実行するHTTPサーバー |
| aeson | JSONのエンコード・デコード |
| hspec | テストフレームワーク本体 |
| hspec-wai | WAI Applicationに対しHTTPリクエストを直接発行してテストする |
| hspec-wai-json | JSONレスポンスをquasi quoterで検証する |
