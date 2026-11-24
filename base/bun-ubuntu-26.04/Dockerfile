# syntax=docker/dockerfile:1

# Bun base on the chiselled Ubuntu 26.04 base (LTS). Bun ships as a single
# binary that links only glibc, libpthread, libdl and libm, so every shared
# library it needs already comes from the common base. This layer adds
# /usr/bin/env so scripts with a `#!/usr/bin/env bun` shebang keep working.
ARG COMMON_BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04
ARG CHISEL_VERSION=v1.5.1

FROM ${COMMON_BASE_IMAGE} AS common

FROM ubuntu:26.04 AS builder

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

# Seed the rootfs with the shared base, then add the Bun-only slices. Chisel
# overwrites existing files, so the final image does not carry duplicate copies
# of the shared base.
COPY --from=common / /rootfs

RUN chisel cut --release ubuntu-26.04 --root /rootfs \
        coreutils_env

FROM scratch

COPY --from=builder /rootfs/ /

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Bun base (Ubuntu 26.04)" \
      org.opencontainers.image.description="Support files shared by the chiselled Ubuntu 26.04 Bun images" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT"
