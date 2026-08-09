# Iteration 5：権限管理・エラー設計

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 4：永続化層の導入](05-iteration-4.md)

## 代数的データ型（ADT）・直和型

```haskell
data UserError
  = Forbidden
  | InvalidEmail Text
  deriving (Show, Eq)
```

`data`で複数の`|`区切りのコンストラクタを持つ型を定義すると、
「このうちのどれか1つである」という**直和型**（Sum Type）になる
（`User`のようにフィールドを複数持つ型は直積型、Product Typeと
呼ばれる。多くのHaskellの`data`宣言はこの2つの組み合わせである）。
`UserError`は「`Forbidden`であるか、`Text`を1つ伴う`InvalidEmail`で
あるかのどちらか」を表す。他言語のenumより表現力が高く（各
コンストラクタが異なる数・型のデータを持てる）、他言語の例外より
軽量（`throw`／`catch`のような制御フローの分岐を必要とせず、ただの
値として扱える）という特徴がある。`case`式でこの値を分岐すると、
GHCは「すべてのコンストラクタを網羅しているか」を検査でき
（`-Wincomplete-patterns`を有効にした場合）、`UserError`に新しい
コンストラクタを追加し忘れて分岐を書き足すのを忘れる、という事故を
コンパイル時に検出できる。

## パターンガード

```haskell
createUserHandler authUser (CreateUserRequest reqName reqEmail)
  | authRole authUser /= Admin = throwUserError Forbidden
  | not (isValidEmail reqEmail) = throwUserError (InvalidEmail reqEmail)
  | otherwise = ...
```

関数定義の引数パターンのあとに`|`で条件式を並べる書き方をパターン
ガードと呼ぶ。上から順に条件を評価し、最初に`True`になった節が使われる
（`if`／`else if`の連鎖に近いが、パターンマッチと組み合わせられる点が
異なる）。`otherwise`は「常に`True`」を表す、慣習的な最後の受け皿で
ある。

## レコード更新構文

```haskell
base { errBody = encode e, errHeaders = jsonContentType : errHeaders base }
```

`value { field = newValue, ... }`は「`value`をコピーし、指定した
フィールドだけを新しい値に差し替えた、新しいレコード値」を作る構文で
ある（元の`value`自体は変更されない。Haskellの値は基本的に
イミュータブルであることを思い出すとよい）。この教材では
`err403`・`err400`のような「Servantが用意した既定の`ServerError`値」
を土台にして、ボディやヘッダだけを差し替える場面で使っている。

---

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 4：永続化層の導入](05-iteration-4.md) ｜ 次へ：[Iteration 6：ロギング・可観測性](07-iteration-6.md)
