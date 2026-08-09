# Iteration 1：ユーザー登録・一覧

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 0：プロジェクト雛形](01-iteration-0.md)

## フィールド名の同一モジュール内一意性制約

Haskellのレコードフィールド名は、同じモジュール内で一意である必要が
ある（Iteration 1の演習1-1で扱うとおり、`User`と`CreateUserRequest`が
どちらも`name`というフィールド名を使おうとすると衝突する）。これは
「フィールドアクセサが、実は普通の関数として生成される」ためである
（`userName :: User -> Text`は`User -> Text`という型を持つ、ただの
トップレベル関数であり、同名の別の関数と共存できない）。回避策として
`userName`・`crName`のようにフィールド名をずらすか、`DuplicateRecordFields`
という拡張機能（本教材では使っていない）を使う方法がある。

## 手書きの`ToJSON`／`FromJSON`

```haskell
instance FromJSON CreateUserRequest where
  parseJSON = withObject "CreateUserRequest" $ \v ->
    CreateUserRequest <$> v .: "name" <*> v .: "email"
```

`withObject`は「JSONの値がオブジェクト（`{...}`）であることを期待して
パースする」ためのヘルパーで、`"CreateUserRequest"`という文字列は
パース失敗時のエラーメッセージに使われるラベルである。`v .: "name"`は
「オブジェクト`v`から`"name"`というキーの値を取り出し、期待する型
（ここでは`Text`）としてパースする」演算子で、キーが存在しなければ
パースは失敗する。`.=`（`ToJSON`側で使う）はその逆で、「キーと値の
ペアを作る」演算子である（`object ["id" .= uid, "name" .= uname]`の
ように使う）。

## `IORef`と`atomicModifyIORef'`

```haskell
newIORef      :: a -> IO (IORef a)
readIORef     :: IORef a -> IO a
writeIORef    :: IORef a -> a -> IO ()
atomicModifyIORef' :: IORef a -> (a -> (a, b)) -> IO b
```

`IORef a`はHaskellにおける「書き換え可能な変数（箱）」である。純粋な
関数型言語であるHaskellでは、値は基本的にイミュータブル（一度作ったら
変更できない）だが、`IORef`を使うと`IO`の中で明示的に「箱の中身を
入れ替える」ことができる。`readIORef`／`writeIORef`はそれぞれ単純な
読み取り・書き込みだが、複数のリクエストが同時に読み書きしうる状況
（Webサーバーのハンドラ）では、「読んでから書く」までの間に別の処理が
割り込んで矛盾した状態になる**競合状態（race condition）**が起こり
うる。`atomicModifyIORef'`は「現在の値を受け取り、（新しい値, 戻り値）
の組を返す関数」を渡すことで、読み取り・計算・書き込みを1つの
分割不可能な操作として実行する（末尾の`'`は「正格評価版」という
Haskellの命名慣習で、遅延評価によるメモリリークを避けるためこちらを
優先して使う）。

## `ReqBody`・`PostCreated`（Verb型）

```haskell
type API = "users" :> ReqBody '[JSON] CreateUserRequest :> PostCreated '[JSON] User
```

`ReqBody '[JSON] CreateUserRequest`は「リクエストボディをJSONとして
パースし、`CreateUserRequest`型の値としてハンドラに渡す」ことを表す
型レベルの指定である。`PostCreated`はHTTPメソッドとステータスコードを
兼ねた「Verb型」の1つで、「POSTリクエストを受け付け、成功時は201
（Created）を返す」ことを表す。`Get`・`Post`・`Delete`など、Servantは
主要なHTTPメソッド・代表的なステータスコードの組み合わせをあらかじめ
型として用意している。

## `:<|>`によるAPI・ハンドラの合成

```haskell
type API = EndpointA :<|> EndpointB

server :: Server API
server = handlerA :<|> handlerB
```

`:<|>`は「2つのエンドポイント（型レベル）」または「2つのハンドラ
（値レベル）」を1つに合成するための演算子である。型のレベルで
`:<|>`を使って組み合わせたAPIは、実装（`Server API`型の値）でも同じ
構造で`:<|>`を使って組み合わせる必要がある。型と実装の構造が対応する
ため、どちらか一方だけ変更すればコンパイルエラーになる。

## qualified import

```haskell
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
```

`import qualified X as Y`は「`X`モジュールの中身を、`Y.`という接頭辞を
付けないと使えない形でインポートする」という意味である。
`Data.Map.Strict`の`insert`と、他のモジュールの`insert`のように、
同名の関数が複数のモジュールに存在することはよくあるため、
`Map.insert`のように出どころを明示してインポートすることで名前の衝突
を避ける。

---

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 0：プロジェクト雛形](01-iteration-0.md) ｜ 次へ：[Iteration 2：認証](03-iteration-2.md)
