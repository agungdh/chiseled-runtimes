# syntax=docker/dockerfile:1

# .NET base on the chiselled Ubuntu 26.10 base. It carries the native
# dependencies that every .NET and ASP.NET Core image on this release needs:
# ICU (globalization), OpenSSL 4 (crypto/TLS), zlib, libstdc++, libgcc_s, the
# Mozilla CA bundle and the timezone database. The runtime itself is added by
# the dotnet/* and aspnet/* images.
#
# Canonical's chisel release for Ubuntu 26.10 does not publish .NET 11 slices
# yet (only 10.0), so the runtime comes from the official Microsoft tarballs.
# ASP.NET Core is part of the .NET platform and needs the exact same native
# dependencies, so both runtimes share this language base.
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

# Seed the rootfs with the shared base, then add the .NET-only slices. Chisel
# overwrites existing files, so the final image does not carry duplicate copies
# of the shared base.
#
# libicu78_libs and tzdata_zoneinfo provide full globalization and time zone
# support (Canonical's dotnet-runtime-*_standard slice uses the same pair).
# libssl4_libs is the OpenSSL 4 runtime that ships in Ubuntu 26.10.
COPY --from=common / /rootfs

RUN chisel cut --release ubuntu-26.10 --root /rootfs \
        libicu78_libs \
        libssl4_libs \
        zlib1g_libs \
        libstdc++6_libs \
        libgcc-s1_libs \
        ca-certificates_data \
        tzdata_zoneinfo

FROM scratch

COPY --from=builder /rootfs/ /

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes .NET base (Ubuntu 26.10)" \
      org.opencontainers.image.description="Native dependencies shared by the chiselled Ubuntu 26.10 .NET and ASP.NET Core images" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT"
