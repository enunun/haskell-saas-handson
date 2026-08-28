FROM haskell:9.14.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    git \
    curl \
    openssh-client \
    libpq-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# GitHub公式ホストのaptリポジトリ（cli.github.com）からghコマンドを導入する。
# DebianディストリビューションのaptリポジトリにあるghはGitHub CLIとは別物のため使用しない。
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | \
    BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_INSTALL_HLS=1 \
    BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1 \
    sh

ENV PATH="/root/.ghcup/bin:${PATH}"

ARG RTK_VERSION=0.45.0

RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) rtk_target="x86_64-unknown-linux-musl" ;; \
        arm64) rtk_target="aarch64-unknown-linux-gnu" ;; \
        *) echo "Unsupported architecture" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${rtk_target}.tar.gz" \
      | tar -xz -C /usr/local/bin rtk; \
    chmod +x /usr/local/bin/rtk

# Iteration 4で導入した宣言的DBマイグレーションツール（PostgreSQL用）。
# db/schema.sqlに書いた「あるべきスキーマ」とDBの現在の状態を比較し、
# 差分（CREATE TABLE・ALTER TABLE等）を自動的に計算・適用する。
ARG SQLDEF_VERSION=3.11.19

RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) sqldef_arch="amd64" ;; \
        arm64) sqldef_arch="arm64" ;; \
        *) echo "Unsupported architecture" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/sqldef/sqldef/releases/download/v${SQLDEF_VERSION}/psqldef_linux_${sqldef_arch}.tar.gz" \
      | tar -xz -C /usr/local/bin psqldef; \
    chmod +x /usr/local/bin/psqldef

WORKDIR /workspace