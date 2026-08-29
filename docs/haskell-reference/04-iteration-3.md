# Iteration 3：マルチテナント対応

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 2：認証](03-iteration-2.md)

## 独自の型クラスを定義する

joseライブラリ（`Crypto.JWT`）は`HasClaimsSet`を次のように定義している。

```haskell
class HasClaimsSet a where
  claimsSet :: Lens' a ClaimsSet
```

`Show`や`Eq`のような、あらかじめ用意された型クラスだけでなく、自分で
新しい型クラスを定義することもできる。`class ... where`のあとに、
そのクラスに属する型が満たすべき操作（メソッド）の型シグネチャを
並べる。`instance HasClaimsSet AuthClaims where claimsSet = ...`の
ように、個々の型に対してその実装を与える。この教材では「標準の
`ClaimsSet`に独自のクレームを追加した型」に共通のインターフェースを
持たせるために使われている（`jose`ライブラリの`verifyJWT`関数が、
`HasClaimsSet`を満たす任意の型を検証対象として受け取れるようにする
ため）。

## `Data.Map.Strict`

containersライブラリの`Data.Map.Strict`は次の関数群を提供している。

```haskell
Map.empty                    :: Map k v
Map.insert   :: k -> v -> Map k v -> Map k v
Map.lookup   :: k -> Map k v -> Maybe v
Map.findWithDefault :: v -> k -> Map k v -> v
```

`Map k v`はキー（`k`）から値（`v`）を引ける連想配列（辞書）である。
キーの型`k`は`Ord`（順序比較ができる）である必要がある（内部的には
平衡二分探索木で実装されている）。`Map.lookup`はキーが存在しなければ
`Nothing`を返す。`Map.findWithDefault d k m`は「キーが存在しなければ
デフォルト値`d`を返す」という、`lookup`＋`Maybe`の分岐をまとめた
ショートカットである。

## 型でドメイン制約を表現する

この教材全体を通じて繰り返し出てくる考え方として、「本来ならコードの
どこかで気をつけて守らなければいけないルール」を、型やデータ構造の
形そのものに落とし込んで、**気をつけなくても間違えられないようにする**
という設計方針がある。例えば`Map TenantId (...)`というデータ構造は、
「あるテナントのデータへアクセスするには必ずテナントIDが要る」ことを
型で強制しており、テナントIDを渡さずに全データへアクセスする関数は
そもそも書けない。同様の考え方は`newtype`（[Iteration 2](03-iteration-2.md)）・
`AuthenticatedUser`型（Iteration 2・3・5）・`UserError`型
（[Iteration 5](06-iteration-5.md)）にも通底している。

---

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 2：認証](03-iteration-2.md) ｜ 次へ：[Iteration 4：永続化層の導入](05-iteration-4.md)
