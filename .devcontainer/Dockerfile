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

WORKDIR /workspace