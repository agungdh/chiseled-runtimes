# syntax=docker/dockerfile:1

# Node.js 26 LTS on the chiselled Ubuntu 26.04 Node.js base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:nodejs-ubuntu-26.04
ARG NODE_VERSION=26.13.1
ARG NODE_SHA256_AMD64=5c063e46bab0fbc1c17cc445d7ff129cbdcd0471be6ed83b6ab864f8143bc864
ARG NODE_SHA256_ARM64=89e1853138db51e8b82d3e98ba9c0d3f2956a28e5e55ea1b7e12d25aae92d5dd

# Node.js 26 is the only LTS here whose official binary links libatomic. The
# Node.js base leaves it out so Node.js 18-24 stay free of it.
FROM ubuntu:26.04 AS extra

RUN apt-get update \
    && apt-get install -y --no-install-recommends libatomic1 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /out \
    && cp -a --parents /usr/lib/*-linux-*/libatomic.so.1* /out/

FROM ubuntu:26.04 AS node

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
    && rm -rf /opt/nodejs/include /opt/nodejs/share/doc /opt/nodejs/share/man \
    && /opt/nodejs/bin/node --version

FROM ${BASE_IMAGE}

ARG NODE_VERSION

COPY --from=extra /out/ /
COPY --from=node /opt/nodejs /opt/nodejs

ENV NODE_VERSION=${NODE_VERSION} \
    HOME=/app \
    PATH=/opt/nodejs/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Node.js 26 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Node.js 26 LTS on a minimal chiselled Ubuntu 26.04 Node.js base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${NODE_VERSION}" \
      org.nodejs.version="${NODE_VERSION}"

USER 10001:10001
WORKDIR /app
