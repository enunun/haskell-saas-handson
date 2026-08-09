# Iteration 0：プロジェクト雛形

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[0章：Haskellの基礎](00-basics.md)

## Servantの型レベルAPI定義

```haskell
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
api :: Proxy API
api = Proxy
```

`API`という型そのものを関数の引数として直接渡すことはできない
（Haskellでは型と値は別の世界に住んでいる）。`Proxy API`は「中身を
持たない、`API`という型の情報だけを運ぶための値」であり、
「この型に対して処理してほしい」とライブラリ関数に伝えるための
定型的な小道具である。`Proxy`自体の値は常に`Proxy`の1通りしかない
（中身がないため）。

## `Handler`モナド

[0章](00-basics.md)で説明したとおり、`Handler`はServantのハンドラが動く文脈を表す
モナドである。`Handler a`の実体は`ExceptT ServerError IO a`
（[Iteration 2の節](03-iteration-2.md)を参照）で、「`IO`の副作用を起こしながら、途中で
`ServerError`を投げて失敗することもできる、`a`型の値を返す計算」を
表す。

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
