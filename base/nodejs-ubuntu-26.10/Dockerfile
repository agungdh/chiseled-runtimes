# syntax=docker/dockerfile:1

# Node.js base on the chiselled Ubuntu 26.10 base. It carries only the files
# that every Node.js version on this release shares: /usr/bin/env (for npm/npx
# shebangs), libstdc++ and libgcc_s (both linked by the official binary).
# libatomic is added by the version that needs it.
ARG COMMON_BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.10
ARG CHISEL_VERSION=v1.5.1

FROM ${COMMON_BASE_IMAGE} AS common

FROM ubuntu:26.10 AS builder

ARG TARGETARCH
ARG CHISEL_VERSION

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
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

# Seed the rootfs with the shared base, then add the Node.js-only slices. Chisel
# overwrites existing files, so the final image does not carry duplicate copies
# of the shared base.
COPY --from=common / /rootfs

RUN chisel cut --release ubuntu-26.10 --root /rootfs \
        coreutils_env \
        libstdc++6_libs

FROM scratch

COPY --from=builder /rootfs/ /

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Node.js base (Ubuntu 26.10)" \
      org.opencontainers.image.description="Node.js support libraries shared by the chiselled Ubuntu 26.10 Node.js images" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT"
