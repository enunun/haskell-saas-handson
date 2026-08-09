FROM haskell:9.14.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    git \
    curl \
    openssh-client \
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

WORKDIR /workspace