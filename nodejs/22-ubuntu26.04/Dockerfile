# syntax=docker/dockerfile:1

# Node.js 22 LTS on the chiselled Ubuntu 26.04 Node.js base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:nodejs-ubuntu-26.04
ARG NODE_VERSION=22.23.5
ARG NODE_SHA256_AMD64=cdeb8670a0c81f51b4dc4ac61919f9b1ad917b304bf8221eb939570663d240f8
ARG NODE_SHA256_ARM64=2babb9eb5264860d540849f4b064a6fbdebcdc323657d9d382ce23d313fd5e09

FROM ubuntu:26.04 AS node

ARG TARGETARCH
ARG NODE_VERSION
ARG NODE_SHA256_AMD64
ARG NODE_SHA256_ARM64

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
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

COPY --from=node /opt/nodejs /opt/nodejs

ENV NODE_VERSION=${NODE_VERSION} \
    HOME=/app \
    PATH=/opt/nodejs/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Node.js 22 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Node.js 22 LTS on a minimal chiselled Ubuntu 26.04 Node.js base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${NODE_VERSION}" \
      org.nodejs.version="${NODE_VERSION}"

USER 10001:10001
WORKDIR /app
