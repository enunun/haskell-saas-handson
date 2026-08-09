# saas-handson-suite

HaskellとServantでtoB SaaSを構築するTDD/アジャイル形式のハンズオン教材。
演習用プロジェクトと解答例プロジェクトを1つのcabalマルチパッケージ構成に
まとめたリポジトリである。

## リポジトリ構成

```
cabal.project              全パッケージを列挙するルート定義（LSPが参照する）
.devcontainer/              VSCode + Dockerによる開発環境定義
saas-handson/                演習用プロジェクト
saas-handson-solution/       解答例プロジェクト
```

`saas-handson`と`saas-handson-solution`は同じAPI仕様・同じテストを持つ
独立したcabalパッケージである。両者は個別のcabal.projectを持たず、
ルートの`cabal.project`が両方を束ねる。

```yaml
# cabal.project
packages:
  saas-handson
  saas-handson-solution
```

haskell-language-serverはこのファイルを起点にプロジェクト構成を解決する
ため、パッケージを追加した際は必ずこのファイルにも追記する。ルートに
列挙されていないパッケージは、たとえディレクトリが存在してもLSPの補完・
型検査・診断の対象外となる。

## 開発環境（VSCode + Dev Container）

このリポジトリは[Dev Containers](https://containers.dev/)に対応している。

1. VSCodeに拡張機能「Dev Containers」（`ms-vscode-remote.remote-containers`）
   をインストールする
2. Dockerを起動した状態でこのリポジトリをVSCodeで開く
3. 右下の通知、またはコマンドパレットから
   「Dev Containers: Reopen in Container」を実行する

コンテナ内には以下が含まれる。

- GHC・cabal（`haskell:9.4.8`イメージ由来）
- haskell-language-server（HLS）
- VSCode拡張機能
  - `haskell.haskell`（公式Haskell拡張、HLS連携）
  - `justusadam.language-haskell`（シンタックスハイライト）
  - `EditorConfig.EditorConfig`

コンテナ起動時に`cabal update`が自動実行される。

## コマンド

コマンドはすべてリポジトリルートから実行する。

```sh
# 演習用プロジェクトのテスト（単体・結合の両方）
cabal test saas-handson

# 解答例プロジェクトのテスト（単体・結合の両方）
cabal test saas-handson-solution

# 単体テスト／結合テストを個別に実行する場合
cabal test saas-handson-solution:test:unit
cabal test saas-handson-solution:test:integration

# 全パッケージをまとめてビルド
cabal build all
```

## 進め方・資料

- 演習の進め方：`saas-handson/README.md`
- 解答例：`saas-handson-solution/README.md`
- 設計パターン・ライブラリの解説：各プロジェクトの`docs/iteration-0.md`,
  `docs/iteration-1.md`
- 全体ロードマップ：各プロジェクトの`docs/ROADMAP.md`
