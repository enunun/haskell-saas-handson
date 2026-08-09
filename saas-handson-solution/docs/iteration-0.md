# Iteration 0：解説

このドキュメントは`saas-handson/docs/iteration-0.md`の演習問題に対応する
解答解説である。見出しの番号（0-1〜0-5）は演習側と対応している。

## 演習0-1の解説：型を読み解く

### 型レベルAPI設計（Type-Level API）

Servantでは、エンドポイントの仕様を値ではなく型で表現する。`API`型は
次のように定義される。

```haskell
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
api :: Proxy API
api = Proxy
```

`API`は型であり値ではないため、実行時に型情報を関数（`serve`）へ渡す
手段がない。そこで`Data.Proxy`の`Proxy`を使う。`Proxy a`は`a`という型
パラメータだけを持ち、実行時には何のデータも保持しないダミー値である。
これにより「`API`という型の情報」を値として関数に渡せるようになる。
型レベル情報を値レベルへ橋渡しするHaskellの定型的な手法であり、Servant
以外のライブラリでも頻出する。

### aesonとGHC.Genericsの組み合わせ

```haskell
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

演習0-1の問い3の答え：`API`は型でしかなく、Haskellの値の世界には存在
しない。`serve`のような関数に「どの型に対応するAPIを組み立てるか」を
伝えるには、その型を値として持ち回れる何かが必要になる。`Proxy`は中身を
持たない値でありながら型パラメータだけは保持するため、この橋渡し役を
果たす。

## 演習0-2の解説：Redを確認する

```sh
cabal test saas-handson
```

を実行すると、単体テスト（`test/unit/HealthSpec.hs`）は`error "TODO:
Iteration 0で実装する"`が例外として送出され失敗する。結合テスト
（`test/integration/HealthSpec.hs`）も同じ理由で`GET /health`が500を
返すため失敗する。両方とも`src/Server.hs`の`healthHandler`が未実装で
あることが原因である。

### hspec-wai：Applicationを直接テストする

```haskell
spec = with (pure app) $
  describe "GET /health" $ do
    it "ステータスコード200を返す" $
      get "/health" `shouldRespondWith` 200
```

hspec-waiは実際にHTTPサーバーを起動することなく、WAI Application相手に
リクエストを発行して結果を検証する。ネットワークやポートに依存しない
ため、テストが高速かつ決定的になる。

### TDDサイクル

1. `test/unit/HealthSpec.hs`と`test/integration/HealthSpec.hs`はすでに
   用意されており、RED（演習0-2）であることを確認する。
2. `src/Server.hs`のハンドラを実装し、両方GREENにする（演習0-3）。
3. 型シグネチャや命名を見直し、テストがGREENのままリファクタリングする
   （演習0-5で自力で体験する）。

このサイクルをイテレーション単位で繰り返すことが本教材の基本方針である。

## 演習0-3の解説：healthHandlerを実装する

```haskell
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
app :: Application
app = serve api server
```

`serve`はAPI型とハンドラから`Network.Wai.Application`を生成する。WAIは
Haskellにおける標準的なWebサーバーインターフェースであり、`app`自体は
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

問い3の答え：Iteration 1でハンドラがバリデーションや状態遷移（採番・
一覧の蓄積）を持ち始めると、単体テストはロジックの分岐やエッジケース
をWeb層なしで高速に検証する役割を、結合テストはルーティング定義や
JSONのフィールド名といった実際にHTTP越しでなければ検出できない不整合
を検証する役割を、それぞれ担うようになる（`docs/iteration-1.md`参照）。

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
機能（User）が加わるIteration 1の冒頭で、技術層別から機能別（Vertical
Slice）への構成変更を明示的なリファクタリングステップとして行う。
`version`フィールドの追加のような「既存の1機能の中で完結する変更」は
技術層別構成のままで問題なく行えることを、この演習で体感できる。

## 使用ライブラリ

| ライブラリ | 役割 |
|---|---|
| servant-server | 型レベルAPI定義からWAI Applicationを生成する |
| warp | WAI Applicationを実行するHTTPサーバー |
| aeson | JSONのエンコード・デコード |
| hspec | テストフレームワーク本体 |
| hspec-wai | WAI Applicationに対しHTTPリクエストを直接発行してテストする |
