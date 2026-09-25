ARG DART_VERSION=3.13.3
ARG RUST_VERSION=1.96.0

FROM docker.io/library/rust:${RUST_VERSION}-bookworm AS rust-toolchain

FROM docker.io/library/dart:${DART_VERSION} AS dart-build

COPY --from=rust-toolchain /usr/local/cargo /usr/local/cargo
COPY --from=rust-toolchain /usr/local/rustup /usr/local/rustup

ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH="/usr/local/cargo/bin:${PATH}"

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    clang \
    cmake \
    curl \
    llvm \
    ninja-build \
    pkg-config \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY packages/noosphere_server/container/workspace_pubspec.yaml ./pubspec.yaml
COPY packages/noosphere packages/noosphere
COPY packages/noosphere_client packages/noosphere_client
COPY packages/noosphere_server packages/noosphere_server
RUN dart pub get

WORKDIR /workspace/packages/noosphere_server
RUN dart build cli --output=/out --target=bin/iroh_server.dart
RUN IROHDART_CACHE_DIR=/tmp/iroh-cache dart run iroh_quic:setup \
  && find /tmp/iroh-cache -type f -name libirohdart_ffi.so \
    -exec cp '{}' /out/bundle/lib/libirohdart_ffi.so \; \
  && test -s /out/bundle/lib/libirohdart_ffi.so

FROM docker.io/library/debian:trixie-slim

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    libgcc-s1 \
  && rm -rf /var/lib/apt/lists/* \
  && install -d -m 0700 /var/lib/noosphere

WORKDIR /app

COPY --from=dart-build /out/bundle/ /app/
COPY packages/noosphere_server/config/iroh-server.example.yaml /config/server.yaml

ENV LD_LIBRARY_PATH="/app/lib:/usr/local/lib"
VOLUME ["/var/lib/noosphere"]

ENTRYPOINT ["/app/bin/iroh_server", "--config"]
CMD ["/config/server.yaml"]
