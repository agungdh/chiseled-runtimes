# syntax=docker/dockerfile:1

# Node.js 20 LTS on the chiselled Ubuntu 26.04 base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04
ARG NODE_VERSION=20.20.2
ARG NODE_SHA256_AMD64=df770b2a6f130ed8627c9782c988fda9669fa23898329a61a871e32f965e007d
ARG NODE_SHA256_ARM64=73093db209e4e9e09dd7d15a47aeaab1b74833830df03efa5f942a1122c5fa71

FROM ubuntu:26.04 AS node

ARG TARGETARCH
ARG NODE_VERSION
ARG NODE_SHA256_AMD64
ARG NODE_SHA256_ARM64

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl libatomic1 xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
        amd64) node_arch="x64"; multiarch="x86_64-linux-gnu"; sha256="${NODE_SHA256_AMD64}" ;; \
        arm64) node_arch="arm64"; multiarch="aarch64-linux-gnu"; sha256="${NODE_SHA256_ARM64}" ;; \
        *) echo "error: unsupported TARGETARCH '${TARGETARCH}'" >&2; exit 1 ;; \
    esac \
    && url="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl -fsSL -o /tmp/node.tar.xz "${url}" \
    && echo "${sha256}  /tmp/node.tar.xz" | sha256sum -c - \
    && mkdir -p /opt/nodejs "/opt/nodejs-deps/usr/bin" "/opt/nodejs-deps/usr/lib/${multiarch}" \
    && tar -xJf /tmp/node.tar.xz -C /opt/nodejs --strip-components=1 \
    && rm -f /tmp/node.tar.xz \
    && rm -rf /opt/nodejs/include /opt/nodejs/share/doc /opt/nodejs/share/man \
    && cp -L /usr/bin/env /opt/nodejs-deps/usr/bin/env \
    && cp -L "/usr/lib/${multiarch}/libatomic.so.1" "/opt/nodejs-deps/usr/lib/${multiarch}/libatomic.so.1" \
    && /opt/nodejs/bin/node --version

FROM ${BASE_IMAGE}

ARG NODE_VERSION

COPY --from=node /opt/nodejs /opt/nodejs

# npm/npx use `#!/usr/bin/env node`, and the official Node.js binary links
# against libatomic. Keep these here instead of in the shared base so Java
# images stay untouched.
COPY --from=node /opt/nodejs-deps/usr/bin/env /usr/bin/env
COPY --from=node /opt/nodejs-deps/usr/lib/ /usr/lib/

ENV NODE_VERSION=${NODE_VERSION} \
    HOME=/app \
    PATH=/opt/nodejs/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Node.js 20 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Node.js 20 LTS on a minimal chiselled Ubuntu 26.04 base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${NODE_VERSION}" \
      org.nodejs.version="${NODE_VERSION}"

USER 10001:10001
WORKDIR /app
