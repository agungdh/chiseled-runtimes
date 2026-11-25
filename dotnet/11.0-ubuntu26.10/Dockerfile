# syntax=docker/dockerfile:1

# .NET 11 runtime (Microsoft.NETCore.App only) on the chiselled Ubuntu 26.10
# .NET base. .NET 11 is an STS release (EOL 2028-11-14). Versions and checksums
# are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:dotnet-ubuntu-26.10
ARG DOTNET_VERSION=11.0.0
ARG DOTNET_SHA512_AMD64=d0846e7ad4a6b07fe3fb7c033a381e6938ec16afbe0b7f7454ff2f9b58247cbbc35758cc785af424385c4572c801060cbd656a822ef624f4907d3cc10a16a080
ARG DOTNET_SHA512_ARM64=b624e647c72e8f62a0d186aa96aad1b113732e8c39f010be6f95ec026feb2633187e33f24c3af5168daaa1d9b4bb0bb9c396f6d172d18660b9673bb507fa9f45

FROM ubuntu:26.10 AS dotnet

ARG TARGETARCH
ARG DOTNET_VERSION
ARG DOTNET_SHA512_AMD64
ARG DOTNET_SHA512_ARM64

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Fetch, verify and unpack the official .NET runtime tarball. Microsoft uses
# `x64` and `arm64` in the file name and publishes SHA-512 checksums in the
# channel's releases.json.
RUN case "${TARGETARCH}" in \
        amd64) dotnet_arch="x64"; sha512="${DOTNET_SHA512_AMD64}" ;; \
        arm64) dotnet_arch="arm64"; sha512="${DOTNET_SHA512_ARM64}" ;; \
        *) echo "error: unsupported TARGETARCH '${TARGETARCH}'" >&2; exit 1 ;; \
    esac \
    && url="https://builds.dotnet.microsoft.com/dotnet/Runtime/${DOTNET_VERSION}/dotnet-runtime-${DOTNET_VERSION}-linux-${dotnet_arch}.tar.gz" \
    && curl -fsSL -o /tmp/dotnet.tar.gz "${url}" \
    && echo "${sha512}  /tmp/dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /opt/dotnet \
    && tar -xzf /tmp/dotnet.tar.gz -C /opt/dotnet \
    && rm -f /tmp/dotnet.tar.gz \
    && /opt/dotnet/dotnet --list-runtimes

FROM ${BASE_IMAGE}

ARG DOTNET_VERSION

COPY --from=dotnet /opt/dotnet /opt/dotnet

ENV DOTNET_VERSION=${DOTNET_VERSION} \
    DOTNET_ROOT=/opt/dotnet \
    DOTNET_RUNNING_IN_CONTAINER=true \
    HOME=/app \
    PATH=/opt/dotnet:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes .NET 11 (Ubuntu 26.10)" \
      org.opencontainers.image.description=".NET 11 runtime on a minimal chiselled Ubuntu 26.10 .NET base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${DOTNET_VERSION}" \
      org.dotnet.version="${DOTNET_VERSION}"

USER 10001:10001
WORKDIR /app
