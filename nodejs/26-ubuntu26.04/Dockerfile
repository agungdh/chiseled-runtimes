# syntax=docker/dockerfile:1

# Node.js 26 LTS on the chiselled Ubuntu 26.04 base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04
ARG CHISEL_VERSION=v1.5.1
ARG NODE_VERSION=26.13.1
ARG NODE_SHA256_AMD64=5c063e46bab0fbc1c17cc445d7ff129cbdcd0471be6ed83b6ab864f8143bc864
ARG NODE_SHA256_ARM64=89e1853138db51e8b82d3e98ba9c0d3f2956a28e5e55ea1b7e12d25aae92d5dd

FROM ubuntu:26.04 AS node

ARG TARGETARCH
ARG CHISEL_VERSION
ARG NODE_VERSION
ARG NODE_SHA256_AMD64
ARG NODE_SHA256_ARM64

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Fetch and verify the chisel binary (https://github.com/canonical/chisel).
RUN filename="chisel_${CHISEL_VERSION}_linux_${TARGETARCH}.tar.gz" \
    && url="https://github.com/canonical/chisel/releases/download/${CHISEL_VERSION}" \
    && curl -fsSL -o "/tmp/${filename}" "${url}/${filename}" \
    && curl -fsSL -o "/tmp/${filename}.sha384" "${url}/${filename}.sha384" \
    && cd /tmp \
    && sha384sum -c "${filename}.sha384" \
    && tar -xzf "${filename}" -C /usr/local/bin chisel \
    && chisel version

RUN case "${TARGETARCH}" in \
        amd64) node_arch="x64"; multiarch="x86_64-linux-gnu"; sha256="${NODE_SHA256_AMD64}" ;; \
        arm64) node_arch="arm64"; multiarch="aarch64-linux-gnu"; sha256="${NODE_SHA256_ARM64}" ;; \
        *) echo "error: unsupported TARGETARCH '${TARGETARCH}'" >&2; exit 1 ;; \
    esac \
    && url="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl -fsSL -o /tmp/node.tar.xz "${url}" \
    && echo "${sha256}  /tmp/node.tar.xz" | sha256sum -c - \
    && mkdir -p /opt/nodejs "/opt/nodejs-deps/usr/bin" "/opt/nodejs-deps/usr/lib/${multiarch}" /tmp/nodejs-deps \
    && tar -xJf /tmp/node.tar.xz -C /opt/nodejs --strip-components=1 \
    && rm -f /tmp/node.tar.xz \
    && rm -rf /opt/nodejs/include /opt/nodejs/share/doc /opt/nodejs/share/man \
    && chisel cut --release ubuntu-26.04 --root /tmp/nodejs-deps \
        coreutils_env \
        libatomic1_libs \
        libstdc++6_libs \
    && cp -a /tmp/nodejs-deps/usr/bin/env /tmp/nodejs-deps/usr/bin/gnuenv /opt/nodejs-deps/usr/bin/ \
    && cp -a "/tmp/nodejs-deps/usr/lib/${multiarch}/libatomic.so.1"* \
             "/tmp/nodejs-deps/usr/lib/${multiarch}/libstdc++.so."* \
             "/tmp/nodejs-deps/usr/lib/${multiarch}/libgcc_s.so."* \
             "/opt/nodejs-deps/usr/lib/${multiarch}/" \
    && rm -rf /tmp/nodejs-deps \
    && /opt/nodejs/bin/node --version

FROM ${BASE_IMAGE}

ARG NODE_VERSION

COPY --from=node /opt/nodejs /opt/nodejs

# npm/npx use `#!/usr/bin/env node`, and the official Node.js binary links
# against libatomic, libstdc++ and libgcc_s. Cut these here instead of
# adding them to the shared base so Java images stay untouched.
COPY --from=node /opt/nodejs-deps/usr/bin/ /usr/bin/
COPY --from=node /opt/nodejs-deps/usr/lib/ /usr/lib/

ENV NODE_VERSION=${NODE_VERSION} \
    HOME=/app \
    PATH=/opt/nodejs/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Node.js 26 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Node.js 26 LTS on a minimal chiselled Ubuntu 26.04 base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${NODE_VERSION}" \
      org.nodejs.version="${NODE_VERSION}"

USER 10001:10001
WORKDIR /app
