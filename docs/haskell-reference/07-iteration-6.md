# Iteration 6：ロギング・可観測性

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 5：権限管理・エラー設計](06-iteration-5.md)

## 型クラスによる変換の多重ディスパッチ

```haskell
class ToLogStr msg where
  toLogStr :: msg -> LogStr
```

`fast-logger`の`ToLogStr`は、「`Text`も`ByteString`も`String`も
`Int`も、それぞれ違う変換方法で`LogStr`に変換できる」ことを表す型
クラスである。呼び出す側は`toLogStr someValue`と書くだけでよく、
`someValue`の型に応じて適切な変換方法がコンパイル時に選ばれる
（＝「型に応じて呼び出す実装を切り替える」という、型クラスの基本的な
使い方の実例である）。

## `IO`のテスト容易性

Iteration 4の`UserRepository`（in-memory実装／PostgreSQL実装、
[Iteration 4の節](05-iteration-4.md)を参照）と
同様に、`Logger`も「標準出力に書き込む本番実装」と「メモリに記録する
だけのテスト用実装」を差し替えられる形にしている。副作用
（`IO`アクション）を直接テストするのは一般に難しいが、「副作用を
実行する部分」を抽象化されたインターフェース（`Logger`）の背後に
隠し、テストでは副作用の代わりに結果を観測できる実装
（`Logging.Capturing`）を注入する、という設計にすることで、
「副作用が起きたこと」自体をテストで検証できるようになる。標準出力
という実際の副作用そのものをテストしたい場合（`Logging.Stdout`の
`writeEntry`）は、`silently`パッケージの`capture_`のように、
「一時的に副作用の出力先を差し替えて捕捉する」ための専用の道具を
使う。

---

[◀ 目次に戻る](../haskell-reference.md) ｜ 前へ：[Iteration 5：権限管理・エラー設計](06-iteration-5.md)
