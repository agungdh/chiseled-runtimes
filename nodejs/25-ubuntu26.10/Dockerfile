# syntax=docker/dockerfile:1

# Node.js 25 (non-LTS) on the chiselled Ubuntu 26.10 Node.js base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:nodejs-ubuntu-26.10
ARG NODE_VERSION=25.9.0
ARG NODE_SHA256_AMD64=1d8db7d6e291d167e8c467ae4094be175e1a0b3969c7ae1f8955b9f7824f7b2e
ARG NODE_SHA256_ARM64=bf007bf0dcc2fddd90888fde374a1ad33c1ab2ca2ad324c645dd7aed0f9f1460

# Node.js 25 links libatomic, just like Node.js 26. The Node.js base leaves it
# out so versions that do not need it stay free of it.
FROM ubuntu:26.10 AS extra

RUN apt-get update \
    && apt-get install -y --no-install-recommends libatomic1 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /out \
    && cp -a --parents /usr/lib/*-linux-*/libatomic.so.1* /out/

FROM ubuntu:26.10 AS node

ARG TARGETARCH
ARG NODE_VERSION
ARG NODE_SHA256_AMD64
ARG NODE_SHA256_ARM64

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# libatomic1 is needed in this builder stage only so the unpacked Node.js
# binary can run `--version`. The final image gets it from the extra stage.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl libatomic1 xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Fetch, verify and unpack the official Node.js tarball.
RUN case "${TARGETARCH}" in \
        amd64) node_arch="x64"; sha256="${NODE_SHA256_AMD64}" ;; \
        arm64) node_arch="arm64"; sha256="${NODE_SHA256_ARM64}" ;; \
        *) echo "error: unsupported TARGETARCH '${TARGETARCH}'" >&2; exit 1 ;; \
    esac \
    && url="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl -fsSL -o /tmp/node.tar.xz "${url}" \
    && echo "${sha256}  /tmp/node.tar.xz" | sha256sum -c - \
    && mkdir -p /opt/nodejs \
    && tar -xJf /tmp/node.tar.xz -C /opt/nodejs --strip-components=1 \
    && rm -f /tmp/node.tar.xz \
    && rm -rf \
        /opt/nodejs/CHANGELOG.md \
        /opt/nodejs/README.md \
        /opt/nodejs/include \
        /opt/nodejs/lib/node_modules/npm/docs \
        /opt/nodejs/lib/node_modules/npm/man \
        /opt/nodejs/share \
    && /opt/nodejs/bin/node --version

FROM ${BASE_IMAGE}

ARG NODE_VERSION

COPY --from=extra /out/ /
COPY --from=node /opt/nodejs /opt/nodejs

ENV NODE_VERSION=${NODE_VERSION} \
    HOME=/app \
    PATH=/opt/nodejs/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Node.js 25 (Ubuntu 26.10)" \
      org.opencontainers.image.description="Node.js 25 (non-LTS) on a minimal chiselled Ubuntu 26.10 Node.js base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${NODE_VERSION}" \
      org.nodejs.version="${NODE_VERSION}"

USER 10001:10001
WORKDIR /app
