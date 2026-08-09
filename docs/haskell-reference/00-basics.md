# 0章：Haskellの基礎

[◀ 目次に戻る](../haskell-reference.md)

Iteration 0に入る前に、この教材のコードを読むために最低限必要な文法・
考え方をまとめる。

## 型シグネチャの読み方

```haskell
add :: Int -> Int -> Int
add x y = x + y
```

`::`は「この左辺は右辺の型を持つ」という意味である。`add`の型
`Int -> Int -> Int`は「`Int`を受け取り、`Int`を受け取り、`Int`を返す
関数」と読む。Haskellの関数は本来「引数を1つだけ受け取り、残りの引数を
受け取る関数を返す」という形（カリー化）になっており、`Int -> Int ->
Int`は実際には`Int -> (Int -> Int)`という意味である。そのため
`add 1`のように引数を一部だけ渡す（部分適用する）と、「残りの1つの
`Int`を受け取って`Int`を返す関数」がそのまま値として得られる。

このハンズオンのコードでは、関数を定義するとき必ず型シグネチャを1行
書く習慣になっている（`createUserHandler :: AuthenticatedUser ->
CreateUserRequest -> Handler User`のように）。実装を読む前に、まず
この1行を読んで「何を受け取って何を返す関数か」を把握するとよい。

## 関数定義・`let`・`where`

```haskell
greet :: Text -> Text
greet name = "Hello, " <> name <> "!"

circleArea :: Double -> Double
circleArea r =
  let piApprox = 3.14159
  in piApprox * r * r

circleArea2 :: Double -> Double
circleArea2 r = piApprox * r * r
  where
    piApprox = 3.14159
```

`let ... in ...`は「これから使うローカルな値に名前を付ける」構文で、
式の中に埋め込んで使う。`where`は関数定義の末尾に「補助的な定義」を
まとめて置く構文で、複数の等式（後述のガード等）から共有して参照できる。
このハンズオンでは`where`の方が頻出する
（`server repo = createUserHandler :<|> listUsersHandler where ...`の
ように、公開する値の下に非公開のヘルパー関数をぶら下げる形でよく使う）。

## パターンマッチと`case`式

```haskell
describe :: Maybe Int -> Text
describe Nothing  = "何もない"
describe (Just n) = "値がある: " <> Text.pack (show n)

describe2 :: Maybe Int -> Text
describe2 m = case m of
  Nothing -> "何もない"
  Just n  -> "値がある: " <> Text.pack (show n)
```

Haskellではif/elseの代わりに「値の形」で分岐することが多い。関数定義を
複数の等式に分けて書く方法（`describe`）と、`case`式でまとめて書く方法
（`describe2`）は同じ意味である。`Just n`のように書くと、`Maybe Int`の
中身を`n`という名前で取り出しながら分岐できる。このハンズオンでは
`Right created <- runHandler (...)`のように、`do`ブロックの中で
パターンマッチを使って値を取り出す書き方が随所に出てくる（値が期待した
形でなければ実行時エラーになる、という割り切った書き方であり、テスト
コードでよく使われる）。

## リストとタプル

`[User]`は「`User`のリスト」、`(Int, [User])`は「`Int`と`[User]`の組
（タプル）」を表す。リストは`map`・`filter`・`++`（連結）といった関数で
操作する。タプルは`fst`・`snd`で1つ目・2つ目の要素を取り出せるほか、
`(nextId, users) = ...`のようにパターンマッチで両方を一度に取り出す
ことが多い。

## `data`宣言とレコード構文

```haskell
data User = User
  { userId    :: Int
  , userName  :: Text
  , userEmail :: Text
  } deriving (Show, Eq)
```

`data`は新しい型を定義するキーワードである。上の例は`User`という型を
定義し、同時に`User`という値コンストラクタ（`Int -> Text -> Text ->
User`という関数）を作る。`{ ... }`はレコード構文で、
`userId`・`userName`・`userEmail`という**フィールドアクセサ**
（`User -> Int`のような関数）が自動的に作られる。`u :: User`があれば
`userId u`でその`id`を取り出せる。既存の値の一部だけを変えた新しい値を
作る「レコード更新構文」（`u { userName = "Bob" }`）は
[Iteration 5の節](06-iteration-5.md)で扱う。

## 型クラスと`deriving`

```haskell
class Show a where
  show :: a -> String
```

型クラスは「ある操作ができる型の集まり」を表す（他言語のインター
フェースに近いが、値ではなく型に対して定義される点が異なる）。上の
`Show`は「`show`で文字列に変換できる型」を表す型クラスで、`Int`や
`Text`は最初から`Show`のインスタンスになっている。自分で定義した型
（`data User = ...`）を`Show`のインスタンスにするには、本来は
`instance Show User where show u = ...`と手で書く必要があるが、多くの
基本的な型クラス（`Show`・`Eq`・`Generic`など）は`deriving`で自動的に
インスタンスを導出できる。

```haskell
data User = User { ... } deriving (Show, Eq)
```

このハンズオンでは`ToJSON`・`FromJSON`（JSON変換）という型クラスが
頻出する。フィールド名とJSONのキー名が一致する場合は
`deriving (Generic)`＋`instance ToJSON User`（中身は空）で自動導出
できるが、一致しない場合は手で書く必要がある（[Iteration 1の節](02-iteration-1.md)を参照）。

## モナドとは何か（概念）

Haskellの関数は基本的に「同じ入力には同じ出力を返す」（副作用を持たない）
ことが期待されている。しかし実際のプログラムは「ファイルを読む」
「DBに書き込む」「失敗するかもしれない」「複数の値を返しうる」といった
「素直な関数」では表せない計算を必要とする。**モナドとは、こうした
「何か特別な文脈を持つ計算」を表す型の総称であり、その文脈を保ったまま
計算をつなげるための共通の作法（インターフェース）**である。

具体例で考えるとイメージしやすい。

- `IO a`：「実行すると副作用を起こしつつ`a`型の値を作り出す手順」を
  表す。`IO Int`は「実行すると`Int`が得られる手順」であり、`Int`その
  ものではない（副作用のある計算と、その結果の値は別物として区別
  されている）。
- `Maybe a`：「`a`が得られるかもしれないし、得られないかもしれない
  （`Nothing`）」という文脈を表す。
- `Either e a`：「`a`が得られるか、`e`型のエラーで失敗するか」という
  文脈を表す。

これらは一見バラバラだが、共通して「文脈を持つ値を作る」
「その中身に関数を適用したい」「複数の“文脈付きの計算”を順番につなげ
たい」という操作が必要になる。この共通の操作の集まりをHaskellでは
`Monad`という型クラスとして抽象化している。他の言語で言えば、
Promiseの`.then`チェーンやOptional/Result型のメソッドチェーンが近い
（「値を直接扱わず、文脈でラップされたまま次の処理につなげる」という
発想は同じである）。

## モナドをどう使うか（実践）

モナドを実際に使うときの中心的な構文が`do`記法である。

```haskell
main :: IO ()
main = do
  putStrLn "名前を教えて"
  name <- getLine
  putStrLn ("こんにちは、" <> name)
```

`do`ブロックは「モナドの文脈の中で、上から順に計算を実行していく」
ことを表す。`name <- getLine`は「`IO String`を実行し、得られた
`String`を`name`という名前に束縛する」という意味である（普通の`=`では
なく`<-`を使う点に注意。`IO String`という“文脈付きの値”そのものではなく
、その中身を取り出して名前を付けている）。

`do`記法は次の2つの操作の組み合わせに展開される（`do`記法は単なる
糖衣構文であり、本質はこの2つである）。

- `pure` / `return`：「文脈を持たないただの値」を、モナドの文脈に
  包む。`pure "ok" :: IO String`は「何もせずに`"ok"`という文字列を
  返すだけのIOアクション」を作る。
- `>>=`（bind、「バインド」と読む）：「文脈付きの計算」と「その中身を
  受け取って次の文脈付きの計算を返す関数」をつなげる。

```haskell
main :: IO ()
main = getLine >>= \name -> putStrLn ("こんにちは、" <> name)
```

上の2つの`main`は同じ意味である。`do`記法は`>>=`の連鎖を読みやすく
書くための構文にすぎない。このハンズオンでは`IO`のほかに、Servantの
`Handler`（`Handler a`は「HTTPハンドラとして実行する、`a`型の値を返す
かエラーを返す計算」を表す、実体は`ExceptT ServerError IO a`という
モナド。詳しくは[Iteration 2の節](03-iteration-2.md)を参照）というモナドが頻出する。

```haskell
healthHandler :: Handler HealthResponse
healthHandler = pure (HealthResponse "ok")
```

このように「モナドの中で値をそのまま返す」ときは`pure`を使う。
`Handler`の中で`IO`のアクション（`readIORef`など）を実行したい場合は
`liftIO`（`IO a -> Handler a`）で持ち上げる必要がある（`Handler`は
`IO`を内部に含む、より大きな文脈だからである）。

```haskell
listUsersHandler :: Handler [User]
listUsersHandler = liftIO (readIORef store)
```

## Functor・Applicative：`<$>`・`<*>`・`fmap`

モナドほど強力ではないが、よく似た「文脈付きの値を扱う」操作として
`Functor`・`Applicative`という型クラスがある。

```haskell
fmap :: (a -> b) -> f a -> f b
(<$>) :: (a -> b) -> f a -> f b   -- fmapの中置演算子版（同じもの）
```

`<$>`（`fmap`）は「文脈の中身に、ただの関数を適用する」操作である。
`show <$> Just 5`は`Just "5"`になる（`Maybe`の中の`5`にだけ`show`を
適用し、`Just`という文脈はそのまま保たれる）。

```haskell
(<*>) :: f (a -> b) -> f a -> f b
```

`<*>`は「文脈に包まれた関数」を「文脈に包まれた値」に適用する操作で、
複数の“文脈付きの値”を1つの関数にまとめて渡すときに使う。このハンズオン
では、複数のJSONフィールドをパースして1つの値にまとめる場面で非常に
よく登場する。

```haskell
instance FromJSON CreateUserRequest where
  parseJSON = withObject "CreateUserRequest" $ \v ->
    CreateUserRequest <$> v .: "name" <*> v .: "email"
```

`v .: "name"`・`v .: "email"`はそれぞれ「パースに失敗するかもしれない
文脈」に包まれた`Text`を表す（`Parser Text`）。
`CreateUserRequest <$> v .: "name"`で「`name`のパースに成功したら、
`CreateUserRequest`コンストラクタ（`Text -> Text ->
CreateUserRequest`）にその値を適用する」という“文脈付きの部分適用”を
行い、続く`<*> v .: "email"`でもう1つの引数を同様に適用している。
「複数のフィールドをそれぞれパースし、すべて成功したら1つの値に
まとめる」という処理を、`if`による分岐や中間変数なしに1行で書ける。

---

[◀ 目次に戻る](../haskell-reference.md) ｜ 次へ：[Iteration 0：プロジェクト雛形](01-iteration-0.md)
