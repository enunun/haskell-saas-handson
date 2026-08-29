# Iteration 0：プロジェクト雛形

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[0章：Haskellの基礎](00-basics.md)

## Servantの型レベルAPI定義

```haskell
-- src/Api.hs
type API = "health" :> Get '[JSON] HealthResponse
```

Servantは「APIの仕様（パス・HTTPメソッド・入出力の形）」をHaskellの
**型**として表現するライブラリである。この1行は「`/health`という
パスへのGETリクエストに対し、JSON形式で`HealthResponse`を返す」という
仕様を、実行時の値ではなく型そのものとして定義している。`:>`は
「パスの要素をつなげる」ための型演算子であり、`'[JSON]`の`'`
（クォート）は「これは値のリストではなく型のリストである」ことを示す
記法（`DataKinds`という言語拡張が有効にする機能）である。仕様が型に
なっているため、実装（`Server API`型の値）が仕様と一致しなければ
コンパイルが通らない。「実装がドキュメントとずれる」という事態が
原理的に起こりにくい。

## `Proxy`

```haskell
-- src/Api.hs
api :: Proxy API
api = Proxy
```

`serve`は`HasServer api context => Proxy api -> Server api -> Application`
という型を持つ（`Servant.Server`）。`api`は型変数であり、実際に使われる
`HasServer`インスタンスは、この`api`が呼び出し時にどの型に決まるかで
決まる。

Haskellの型変数は、関数に渡した引数の型と関数の型シグネチャを照合する
こと（unification）で決まる。`API`という型そのものを引数として直接
渡す構文はないため、`api`を`API`に決めさせるには「型が`Proxy API`
である値」を渡す必要がある。`Proxy a`はコンストラクタが1つ
（`Proxy`）・フィールドが0個の型であり、実行時のデータを何も運ばない。
`api :: Proxy API`という値を`serve`に渡すと、引数の型`Proxy api`と
実際の値の型`Proxy API`が照合され、`api`が`API`に決まる。つまり
`Proxy`は、データを一切運ばずに型変数だけを確定させるための値である。

（`TypeApplications`拡張を使えば`serve @API server`のように型を直接
指定でき、`Proxy`値を渡さずに同じことができる。`Proxy`はその拡張が
広まる前から使われてきた、値の型を介して型変数を確定させる定型的な
手法である。）

## `Handler`モナド

[0章](00-basics.md)で説明したとおり、`Handler`はServantのハンドラが動く文脈を表す
モナドである。`Handler a`の実体は`ExceptT ServerError IO a`
（[Iteration 2の節](03-iteration-2.md)を参照）で、「`IO`の副作用を起こしながら、途中で
`ServerError`を投げて失敗することもできる、`a`型の値を返す計算」を
表す。

## 言語拡張（`{-# LANGUAGE ... #-}`）

Iteration 0のコードでは次の4つを使っている。

- `DataKinds`：`'[JSON]`のように型のリストを書けるようにする（`API`型
  の`'[JSON]`を参照）。これがないと`'[JSON]`という記法自体が構文
  エラーになる。
- `TypeOperators`：`:>`のような記号の名前を、中置の型演算子として型
  シグネチャの中で使えるようにする。`type API = "health" :> Get
  '[JSON] HealthResponse`の`:>`はこの拡張がないと型として解釈できない。
- `DeriveGeneric`：`deriving (Generic)`を使えるようにする。`Generic`は
  標準の`deriving`対象ではないため、この拡張なしに`HealthResponse`へ
  `deriving (Generic)`を付けるとコンパイルエラーになる。
- `OverloadedStrings`：文字列リテラル（`"ok"`）を、文脈に応じて`Text`
  など`String`以外の型としても扱えるようにする。`src/Server.hs`の
  `pure (HealthResponse "ok")`では`status`フィールドが`Text`型なので、
  この拡張がないと`"ok"`は`String`型に決まってしまいコンパイルが通ら
  ない。

`test/integration/HealthSpec.hs`（解答例）ではさらに`QuasiQuotes`も
使っている。`[json|{status:"ok"}|]`という`[quoter名| ... |]`の構文
自体が`QuasiQuotes`を有効にしないと解釈されず、構文エラーになる
（`json`はhspec-wai-jsonが提供するquasi quoter）。

## `.cabal`ファイルの読み方

`.cabal`ファイルはHaskellのパッケージ（ビルドの単位）を定義する
設定ファイルである。

- `library`：他から`import`できるモジュール群。`exposed-modules`に
  公開するモジュール名を列挙する。
- `executable <name>`：実行可能ファイル。`main-is`でエントリポイントの
  ファイルを指定する。
- `test-suite <name>`：テスト実行の単位。`other-modules`にテスト
  モジュールを列挙する。
- `build-depends`：そのスタンザ（`library`/`executable`/`test-suite`
  の各ブロック）が使う外部パッケージ（`aeson`・`servant-server`等）の
  一覧。ここに書かれていないパッケージは、たとえ手元にインストール
  されていても`import`できない。
- `hs-source-dirs`：ソースファイルを探すディレクトリ。

新しいモジュールファイルを追加したのに`Could not find module`のような
エラーが出る場合、多くは`.cabal`の`exposed-modules`／`other-modules`
への追記忘れが原因である。

## hspec・hspec-waiの基本

hspecの基本構文を、単純化した例で示す（実際の`test/unit/HealthSpec.hs`
は`healthHandler`ではなく`mkServer`を`runHandler`に渡す）。

```haskell
spec :: Spec
spec = describe "healthHandler（単体）" $
  it "statusフィールドにokを返す" $ do
    result <- runHandler healthHandler
    result `shouldBe` Right (HealthResponse "ok")
```

`describe`はテストのグループ、`it`は個々のテストケースを表す
（`describe`の中に複数の`it`をネストできる）。`shouldBe`は「左辺と
右辺が等しいことを確認する」アサーションである（内部的には`Eq`型
クラスの`==`を使う。テスト対象の型が`Eq`を導出していないと使えない）。
結合テストで使う`hspec-wai`は、実際にWAI（WebアプリケーションI/Fの
標準）の`Application`にリクエストを送って検証するための拡張である
（`get "/health" \`shouldRespondWith\` 200`のように書く）。

---

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[0章：Haskellの基礎](00-basics.md) ｜ 次へ：[Iteration 1：ユーザー登録・一覧](02-iteration-1.md)
