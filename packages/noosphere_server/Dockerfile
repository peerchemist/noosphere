ARG DART_VERSION=3.13.3
ARG RUST_VERSION=1.96.0
ARG FROSTY_REVISION=dd921490f0cd6696328e89b18de767d87ed680a4
ARG SECP256K1_REVISION=e3a885d42a7800c1ccebad94ad1e2b82c4df5c65

FROM docker.io/library/debian:bookworm AS secp256k1-build
ARG SECP256K1_REVISION

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    autoconf \
    automake \
    git \
    libtool \
    pkg-config \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/bitcoin-core/secp256k1.git \
  && cd secp256k1 \
  && git checkout "${SECP256K1_REVISION}"

WORKDIR /src/secp256k1
RUN ./autogen.sh \
  && ./configure \
    --prefix=/out/install \
    --enable-module-recovery \
    --disable-tests \
    --disable-exhaustive-tests \
    --disable-benchmark \
    CFLAGS="-O2" \
  && make -j"$(nproc)" \
  && make install \
  && cp /out/install/lib/libsecp256k1.so /out/libsecp256k1.so

FROM docker.io/library/rust:${RUST_VERSION}-bookworm AS frosty-build
ARG FROSTY_REVISION

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    clang \
    cmake \
    curl \
    pkg-config \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN curl -fsSL \
    "https://github.com/peerchemist/frosty/archive/${FROSTY_REVISION}.tar.gz" \
    -o frosty.tar.gz \
  && mkdir frosty \
  && tar -xzf frosty.tar.gz --strip-components=1 -C frosty

WORKDIR /src/frosty/frosty_flutter/rust
RUN mkdir -p /out \
  && cargo build --locked --release \
  && cp target/release/libfrosty_rust.so /out/libfrosty_rust.so

FROM docker.io/library/dart:${DART_VERSION} AS dart-build

WORKDIR /workspace
COPY packages/noosphere_server/container/workspace_pubspec.yaml ./pubspec.yaml
COPY packages/noosphere packages/noosphere
COPY packages/noosphere_client packages/noosphere_client
COPY packages/noosphere_server packages/noosphere_server
RUN dart pub get
RUN mkdir -p /out \
  && IROHDART_CACHE_DIR=/tmp/iroh-cache dart run iroh_quic:setup \
  && find /tmp/iroh-cache -type f -name libirohdart_ffi.so \
    -exec cp '{}' /out/libirohdart_ffi.so \; \
  && test -s /out/libirohdart_ffi.so

WORKDIR /workspace/packages/noosphere_server
RUN dart compile exe bin/iroh_server.dart -o /out/noosphere_server

FROM docker.io/library/debian:bookworm-slim

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    libgcc-s1 \
  && rm -rf /var/lib/apt/lists/* \
  && install -d -m 0700 /var/lib/noosphere

WORKDIR /app

COPY --from=dart-build /out/noosphere_server /app/noosphere_server
COPY --from=frosty-build /out/libfrosty_rust.so /app/build/libfrosty_rust.so
COPY --from=dart-build /out/libirohdart_ffi.so /app/build/libirohdart_ffi.so
COPY --from=secp256k1-build /out/libsecp256k1.so /app/build/libsecp256k1.so
COPY packages/noosphere_server/config/iroh-server.example.yaml /config/server.yaml

ENV LD_LIBRARY_PATH="/app/build:/usr/local/lib"
VOLUME ["/var/lib/noosphere"]

ENTRYPOINT ["/app/noosphere_server", "--config"]
CMD ["/config/server.yaml"]
