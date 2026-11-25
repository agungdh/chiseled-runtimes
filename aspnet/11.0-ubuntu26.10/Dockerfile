# syntax=docker/dockerfile:1

# ASP.NET Core 11 runtime on the chiselled Ubuntu 26.10 .NET base. The
# aspnetcore-runtime tarball already contains both Microsoft.NETCore.App and
# Microsoft.AspNetCore.App, so this image is standalone. Versions and
# checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:dotnet-ubuntu-26.10
ARG ASPNET_VERSION=11.0.0
ARG ASPNET_SHA512_AMD64=4f94d65a7c534b82d25153e1c740d1a87d9bcbc9187935d69fb14f9dde5fb284e69302bde3fe2818ff96e9ac0c62d4385aaa68d8f6f3cb6002aa39c859a252f3
ARG ASPNET_SHA512_ARM64=11a625c5a16627cfb301795670f3ee21deb40b0d1f16aca401251b3b5ab10205cb5ef84cdaa2725a4e6a9a627ecb9ee582318b76081503975fedab884ef7ea48

FROM ubuntu:26.10 AS aspnet

ARG TARGETARCH
ARG ASPNET_VERSION
ARG ASPNET_SHA512_AMD64
ARG ASPNET_SHA512_ARM64

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Fetch, verify and unpack the official ASP.NET Core runtime tarball. Microsoft
# uses `x64` and `arm64` in the file name and publishes SHA-512 checksums in the
# channel's releases.json.
RUN case "${TARGETARCH}" in \
        amd64) aspnet_arch="x64"; sha512="${ASPNET_SHA512_AMD64}" ;; \
        arm64) aspnet_arch="arm64"; sha512="${ASPNET_SHA512_ARM64}" ;; \
        *) echo "error: unsupported TARGETARCH '${TARGETARCH}'" >&2; exit 1 ;; \
    esac \
    && url="https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/${ASPNET_VERSION}/aspnetcore-runtime-${ASPNET_VERSION}-linux-${aspnet_arch}.tar.gz" \
    && curl -fsSL -o /tmp/aspnet.tar.gz "${url}" \
    && echo "${sha512}  /tmp/aspnet.tar.gz" | sha512sum -c - \
    && mkdir -p /opt/dotnet \
    && tar -xzf /tmp/aspnet.tar.gz -C /opt/dotnet \
    && rm -f /tmp/aspnet.tar.gz \
    && /opt/dotnet/dotnet --list-runtimes

FROM ${BASE_IMAGE}

ARG ASPNET_VERSION

COPY --from=aspnet /opt/dotnet /opt/dotnet

ENV ASPNET_VERSION=${ASPNET_VERSION} \
    DOTNET_VERSION=${ASPNET_VERSION} \
    DOTNET_ROOT=/opt/dotnet \
    DOTNET_RUNNING_IN_CONTAINER=true \
    ASPNETCORE_HTTP_PORTS=8080 \
    HOME=/app \
    PATH=/opt/dotnet:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes ASP.NET Core 11 (Ubuntu 26.10)" \
      org.opencontainers.image.description="ASP.NET Core 11 runtime on a minimal chiselled Ubuntu 26.10 .NET base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${ASPNET_VERSION}" \
      org.aspnetcore.version="${ASPNET_VERSION}"

USER 10001:10001
WORKDIR /app
