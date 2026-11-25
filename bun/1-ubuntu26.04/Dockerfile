# syntax=docker/dockerfile:1

# Bun 1 on the chiselled Ubuntu 26.04 LTS Bun base. Bun has no non-LTS line,
# so there is only one Ubuntu release to track. Versions and checksums are
# pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:bun-ubuntu-26.04
ARG BUN_VERSION=1.4.5
ARG BUN_SHA256_AMD64=94559b3b528995a49452f9f2404cec74f2efd7d06e0a000a8cd214b02c3666eb
ARG BUN_SHA256_ARM64=18656a3bf0ea5641f5796ae4213b75255579a70a0fded2f337933785568cdf84

FROM ubuntu:26.04 AS bun

ARG TARGETARCH
ARG BUN_VERSION
ARG BUN_SHA256_AMD64
ARG BUN_SHA256_ARM64

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

# Fetch, verify and unpack the official Bun release. Bun publishes arm64 as
# `aarch64` and amd64 as `x64`.
RUN case "${TARGETARCH}" in \
        amd64) bun_arch="x64"; sha256="${BUN_SHA256_AMD64}" ;; \
        arm64) bun_arch="aarch64"; sha256="${BUN_SHA256_ARM64}" ;; \
        *) echo "error: unsupported TARGETARCH '${TARGETARCH}'" >&2; exit 1 ;; \
    esac \
    && url="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${bun_arch}.zip" \
    && curl -fsSL -o /tmp/bun.zip "${url}" \
    && echo "${sha256}  /tmp/bun.zip" | sha256sum -c - \
    && unzip -q /tmp/bun.zip -d /tmp/bun \
    && install -d /opt/bun/bin \
    && install -m 0755 "/tmp/bun/bun-linux-${bun_arch}/bun" /opt/bun/bin/bun \
    && rm -rf /tmp/bun /tmp/bun.zip \
    && /opt/bun/bin/bun --version

FROM ${BASE_IMAGE}

ARG BUN_VERSION

COPY --from=bun /opt/bun /opt/bun

ENV BUN_VERSION=${BUN_VERSION} \
    HOME=/app \
    PATH=/opt/bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Bun 1 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Bun 1 on a minimal chiselled Ubuntu 26.04 LTS Bun base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${BUN_VERSION}" \
      org.bun.version="${BUN_VERSION}"

USER 10001:10001
WORKDIR /app
