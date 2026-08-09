# Iteration 2：認証

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 1：ユーザー登録・一覧](02-iteration-1.md)

## `newtype`

```haskell
newtype TenantId = TenantId { unTenantId :: Text } deriving (Show, Eq, Ord)
```

`newtype`は`data`とよく似ているが、「既存の型（ここでは`Text`）を
そのまま包むだけの、コンストラクタを1つしか持たない型」専用の宣言
である。実行時の表現は中身の型（`Text`）と全く同じ（コンパイル後は
オーバーヘッドが消える）でありながら、コンパイル時には別の型として
扱われる。これにより「テナントIDのつもりで書いたら実は名前だった」の
ような取り違えを型検査の時点で防げる（`Text`のままだと`TenantId`と
`Text`の値が混ざっても検出できないが、`newtype`で包むと別の型に
なるため検出できる）。

## 型族（type family）

```haskell
type family AuthServerData a :: Type
type instance AuthServerData (AuthProtect "jwt") = AuthenticatedUser
```

型族は「型を受け取って型を返す関数」のようなものである。
`AuthServerData`はServantが用意した型族で、「`AuthProtect`の
タグ（`"jwt"`のような型レベル文字列）ごとに、認証成功時にどんな型の
値が得られるか」を定義するために使われている。`type instance`は
「特定の入力に対する型族の“実装”」を1つ与える宣言であり、これにより
`AuthProtect "jwt"`というタグと`AuthenticatedUser`という型が
結び付けられる。値の世界の関数と対になる、型の世界の“関数”だと考える
とよい。

## モナド変換子・`ExceptT`・`MonadError`

```haskell
type Handler = ExceptT ServerError IO
```

`ExceptT e m a`は「`m`というモナドに、`e`型のエラーで早期終了できる
機能を追加した」モナド変換子である。`ExceptT ServerError IO a`は
「`IO`の副作用を起こしながら、途中で`ServerError`を投げて失敗する
こともできる`a`型の計算」を表す。`MonadError e m`は「`m`が`throwError`
（`e`型のエラーを投げる）を使えるモナドである」ことを表す型クラスで、
`Handler`の実体である`ExceptT ServerError IO`はこのクラスの
インスタンスになっている。

```haskell
throwError (err401 { errBody = "..." })
```

この教材では「認証に失敗したら401を投げる」「ロールが足りなければ
403を投げる」といった場面で`throwError`が頻出する。`do`ブロックの
途中で`throwError`が実行されると、それ以降の処理は実行されず、
`Handler`全体が失敗（`Left`）で終わる。

## `Either`

```haskell
data Either e a = Left e | Right a
```

`Either e a`は「`e`型のエラー（`Left`）か`a`型の成功した値
（`Right`）のどちらか」を表す型である。`runHandler`のようにモナドの
計算を実行して結果を取り出す関数は、多くの場合
`IO (Either ServerError a)`のような型を返す。テストコードで
`Right created <- runHandler (...)`のようにパターンマッチしている
のは、「成功（`Right`）することを期待し、失敗したらテスト自体が
エラーで落ちる」という書き方である。

## Lens入門（`^?`・`_Just`）

```haskell
claims ^? claimSub . _Just . string
```

Lens（正確にはこの教材で使うのは`Prism`という関連する概念も含む）は
「ネストしたデータ構造の一部を、取得・更新するための合成可能な部品」
である。`^?`（`preview`）は「値を取り出そうとして、取り出せなければ
`Nothing`を返す」演算子、`_Just`は「`Maybe`が`Just`のときだけ中身を
通す」部品、`string`は「`StringOrURI`という型が実は文字列だった場合
だけ`Text`として取り出す」部品である。`.`でこれらをつなげることで、
「`claims`から`sub`クレームを取り出し、それが存在すれば、それが
文字列であれば、その文字列を返す」という一連の処理を1行で表現して
いる。生のレコードアクセサ（`userId u`のような）と違い、Lensは
「失敗するかもしれない・ネストした・複雑なアクセス」を統一的な記法で
扱える（この教材でLensを使っているのは`jose`ライブラリがLensベースの
APIを提供しているためであり、それ以外の自作コードでは通常のレコード
アクセサで十分である）。

## `Data.Text`と`String`

Haskellの`String`は`[Char]`（文字のリスト）の型エイリアスであり、
シンプルだが大きな文字列の処理には効率が悪い。`Data.Text`の`Text`型は
文字列処理に最適化された型で、実務のHaskellコードでは`String`より
`Text`が好んで使われる。このハンズオンでも`User`の`name`・`email`等は
すべて`Text`である。`OverloadedStrings`という言語拡張を有効にすると、
`"alice"`のような文字列リテラルを`String`だけでなく`Text`としても
そのまま使えるようになる（この教材のファイルの多くが
`{-# LANGUAGE OverloadedStrings #-}`を先頭に書いているのはこのため
である）。

---

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 1：ユーザー登録・一覧](02-iteration-1.md) ｜ 次へ：[Iteration 3：マルチテナント対応](04-iteration-3.md)
