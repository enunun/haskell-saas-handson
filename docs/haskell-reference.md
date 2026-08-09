# 困ったときのHaskellリファレンス

このドキュメントは、`saas-handson`（演習）・`saas-handson-solution`
（解答例）の演習本編（`docs/iteration-0.md`〜`docs/iteration-6.md`）とは
**別立て**の補助資料である。Haskellをほとんど知らない状態でこのハンズオン
を始めた人が、演習中に出てきたコードの意味が分からず立ち止まったときに
参照することを想定している。

- 最初から通読する必要はない。「詰まったら開く」使い方でよい。
- 演習本編がこのファイルにリンクすることは（意図的に）していない。
  本編は本編で完結させ、Haskell自体の説明はここに集約している。
- 章立ては、この教材のIteration 0〜6を進める中で**その概念が初めて
  必要になる順番**に合わせている。あるIterationの節を読むには、それより
  前の章の内容を知っている前提で書いている。
- 教材のビジネスロジック自体（`User`とは何か、`AuthenticatedUser`とは
  何か等）の説明はしない。それは演習本編・解答解説の役割である。ここで
  説明するのは、あくまで「そのコードを読み書きするために必要な
  Haskell・ライブラリ一般の知識」である。
- 内容が長くなったため、章ごとに`docs/haskell-reference/`配下のファイルに
  分割している。このファイルは目次（インデックス）である。

## 目次

| 章 | 内容 |
|---|---|
| [0章：Haskellの基礎](haskell-reference/00-basics.md) | 型シグネチャ・`let`/`where`・パターンマッチ・`data`/レコード・型クラス・モナド（概念と実践）・Functor/Applicative |
| [Iteration 0：プロジェクト雛形](haskell-reference/01-iteration-0.md) | ServantのAPI型定義・`Proxy`・`Handler`モナド・`.cabal`ファイル・hspec |
| [Iteration 1：ユーザー登録・一覧](haskell-reference/02-iteration-1.md) | レコードフィールド名の制約・`ToJSON`/`FromJSON`・`IORef`・`ReqBody`/`PostCreated`・`:<|>`・qualified import |
| [Iteration 2：認証](haskell-reference/03-iteration-2.md) | `newtype`・型族・`ExceptT`/`MonadError`・`Either`・Lens入門・`Data.Text` |
| [Iteration 3：マルチテナント対応](haskell-reference/04-iteration-3.md) | 独自の型クラス定義・`Data.Map.Strict`・型でドメイン制約を表現する |
| [Iteration 4：永続化層の導入](haskell-reference/05-iteration-4.md) | Handleパターン（DI）・クロージャによる状態の隠蔽・`MVar`・`postgresql-simple`・orphan instance |
| [Iteration 5：権限管理・エラー設計](haskell-reference/06-iteration-5.md) | 代数的データ型（ADT）・パターンガード・レコード更新構文 |
| [Iteration 6：ロギング・可観測性](haskell-reference/07-iteration-6.md) | 型クラスによる多重ディスパッチ・`IO`のテスト容易性 |

各ファイルの先頭・末尾には目次への戻りリンクと前後の章へのリンクがある。
