# 0章：Haskellの基礎

[◀ 目次に戻る](../haskell-reference.md)

Iteration 0に入る前に、この教材のコードを読むために最低限必要な文法・
考え方をまとめる。

## 言語拡張とは

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Server (...) where
```

Haskellの言語仕様には`Haskell2010`という標準がある。GHCは標準に加えて
「言語拡張」という追加の構文・型システムの機能を多数持つが、これらは
既定では無効になっている。ファイル先頭に書く`{-# LANGUAGE 拡張名 #-}`
というプラグマは、そのファイルの中でだけ指定した拡張を有効にする
（`.cabal`の`default-extensions`でパッケージ全体に対して有効にする
こともできる）。

拡張を有効にしていないコードは、その拡張が可能にする構文・型システムの
振る舞いを単に使えない。例えば`deriving (Generic)`は`DeriveGeneric`
という拡張を有効にして初めて書ける（標準の`deriving`が対応する型クラス
に`Generic`は含まれていないため）。有効にし忘れると、その構文の部分で
コンパイルエラーになる。

このハンズオンでは、各Iterationのリファレンス（`01-iteration-0.md`
以降）が、そのIterationのコードに新たに登場する拡張だけを、どの行の
どんな構文・型を可能にしているかとセットで具体的に説明する。

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

Haskellの関数は同じ入力に対して常に同じ値を返し、副作用を持たない。
一方で実際のプログラムには、ファイルの読み書き・失敗しうる計算・
複数の結果を返す計算など、値をそのまま返すだけでは表現できない処理が
ある。Haskellではこれらを、結果の型`a`を`IO a`・`Maybe a`・
`Either e a`のように別の型で包んで表現する。

- `IO a`：実行すると副作用を起こしながら`a`型の値を生成する手続きを
  表す型。`IO Int`という型の値そのものは`Int`ではなく、実行して初めて
  `Int`が得られる。
- `Maybe a`：`a`型の値が得られる場合（`Just a`）と得られない場合
  （`Nothing`）の両方を表す型。
- `Either e a`：`a`型の値が得られる場合（`Right a`）と、`e`型の値で
  失敗する場合（`Left e`）の両方を表す型。

`IO`・`Maybe`・`Either`はいずれも、`a`型の値を`m a`型に変換する操作
（`pure`/`return`）と、`m a`型の値と`a -> m b`型の関数から`m b`型の
値を作る操作（`>>=`）を持つ。この2つの操作を備えた型をHaskellでは
`Monad`という型クラスとして定義している。

## モナドをどう使うか（実践）

モナドを実際に使うときの中心的な構文が`do`記法である。

```haskell
main :: IO ()
main = do
  putStrLn "名前を教えて"
  name <- getLine
  putStrLn ("こんにちは、" <> name)
```

`do`ブロックは、モナドの値を上から順に実行していく構文である。
`name <- getLine`は、`IO String`型の計算を実行し、得られた`String`を
`name`という名前に束縛する（`=`ではなく`<-`を使う点に注意する。
`getLine`の型は`IO String`であり、`name`に束縛されるのはそれを実行した
結果の`String`である）。

`do`記法は次の2つの操作の組み合わせに展開される（`do`記法は単なる
糖衣構文であり、本質はこの2つである）。

- `pure` / `return`：`a`型の値を`m a`型（モナドの値）に変換する。
  `pure "ok" :: IO String`は、副作用を起こさず`"ok"`という文字列を
  返すだけの`IO String`の値になる。
- `>>=`（bind、「バインド」と読む）：`m a`型の値と、`a -> m b`型の
  関数を受け取り、`m b`型の値を返す。

```haskell
main :: IO ()
main = getLine >>= \name -> putStrLn ("こんにちは、" <> name)
```

上の2つの`main`は同じ意味である。`do`記法は`>>=`の連鎖を読みやすく
書くための構文にすぎない。このハンズオンでは`IO`のほかに、Servantの
`Handler`というモナドが頻出する。`Handler a`の実体は
`ExceptT ServerError IO a`で、`a`型の値を返すか`ServerError`型の値で
失敗するHTTPハンドラの計算を表す（詳しくは[Iteration 2の節](03-iteration-2.md)を参照）。

```haskell
healthHandler :: Handler HealthResponse
healthHandler = pure (HealthResponse "ok")
```

このように、モナドの値をそのまま返すときは`pure`を使う。`Handler`の中で
`IO`のアクション（`readIORef`など）を実行したい場合は`liftIO`
（`IO a -> Handler a`）で変換する必要がある（`Handler`の実体である
`ExceptT ServerError IO a`は内部に`IO`を含む型だからである）。

```haskell
listUsersHandler :: Handler [User]
listUsersHandler = liftIO (readIORef store)
```

## Functor・Applicative：`<$>`・`<*>`・`fmap`

モナドより持つ操作が少ないが、`f a`型の値を扱う型クラスとして
`Functor`・`Applicative`がある。

```haskell
fmap :: (a -> b) -> f a -> f b
(<$>) :: (a -> b) -> f a -> f b   -- fmapの中置演算子版（同じもの）
```

`<$>`（`fmap`）は、`f a`型の値の中身に関数を適用し、同じ`f`に包んだ
結果を返す操作である。`show <$> Just 5`は`Just "5"`になる（`Just`に
包まれた`5`に`show`を適用し、結果を`Just`のまま返す）。

```haskell
(<*>) :: f (a -> b) -> f a -> f b
```

`<*>`は、`f (a -> b)`型の値（関数を包んだ値）を`f a`型の値に適用し、
`f b`型の値を返す操作である。複数の`f`型の値を1つの関数にまとめて
渡したいときに使う。このハンズオンでは、複数のJSONフィールドをパース
して1つの値にまとめる場面でよく使う。

```haskell
instance FromJSON CreateUserRequest where
  parseJSON = withObject "CreateUserRequest" $ \v ->
    CreateUserRequest <$> v .: "name" <*> v .: "email"
```

`v .: "name"`・`v .: "email"`はそれぞれ`Parser Text`型の値である
（パースに失敗する可能性がある`Text`を表す）。
`CreateUserRequest <$> v .: "name"`は、`name`のパースに成功した場合に
`CreateUserRequest`コンストラクタ（`Text -> Text -> CreateUserRequest`）
へその値を適用した`Parser (Text -> CreateUserRequest)`を作る。続く
`<*> v .: "email"`でこの関数に`email`のパース結果を適用し、
`Parser CreateUserRequest`を得る。複数のフィールドをそれぞれパースし、
すべて成功した場合だけ1つの値にまとめる処理を、`if`による分岐や中間
変数なしに1行で書ける。

---

[◀ 目次に戻る](../haskell-reference.md) ｜ 次へ：[Iteration 0：プロジェクト雛形](01-iteration-0.md)
