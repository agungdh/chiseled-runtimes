# syntax=docker/dockerfile:1

# Liberica JRE 21 (JRE only, without JavaFX) on the chiselled Ubuntu 26.04 Java base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:java-ubuntu-26.04
ARG LIBERICA_VERSION=21.0.13.1+5
ARG LIBERICA_SHA256_AMD64=99d36865ef3d3ba73ce5a95cf59bef3f651e5fe29b5dffb3447a05d8426a13d8
ARG LIBERICA_SHA256_ARM64=2797e3f82f8a7016e5e38f3b88ac07912da672fdc9c93401665f7c4ce0a920ce

FROM ubuntu:26.04 AS jre

ARG TARGETARCH
ARG LIBERICA_VERSION
ARG LIBERICA_SHA256_AMD64
ARG LIBERICA_SHA256_ARM64

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Fetch and verify the Liberica JRE.
RUN case "${TARGETARCH}" in \
        amd64) jre_arch="amd64"; sha256="${LIBERICA_SHA256_AMD64}" ;; \
        arm64) jre_arch="aarch64"; sha256="${LIBERICA_SHA256_ARM64}" ;; \
        *) echo "error: unsupported TARGETARCH '${TARGETARCH}'" >&2; exit 1 ;; \
    esac \
    && url="https://github.com/bell-sw/Liberica/releases/download/${LIBERICA_VERSION}/bellsoft-jre${LIBERICA_VERSION}-linux-${jre_arch}.tar.gz" \
    && curl -fsSL -o /tmp/liberica.tar.gz "${url}" \
    && echo "${sha256}  /tmp/liberica.tar.gz" | sha256sum -c - \
    && mkdir -p /opt/java/openjdk \
    && tar -xzf /tmp/liberica.tar.gz -C /opt/java/openjdk --strip-components=1 \
    && rm -f /tmp/liberica.tar.gz \
    && /opt/java/openjdk/bin/java -version

FROM ${BASE_IMAGE}

COPY --from=jre /opt/java/openjdk /opt/java/openjdk

ARG LIBERICA_VERSION

ENV JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Java 21 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Liberica JRE 21 on a minimal chiselled Ubuntu 26.04 Java base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="GPL-2.0-only WITH Classpath-exception-2.0" \
      org.opencontainers.image.version="${LIBERICA_VERSION}" \
      com.bellsoft.liberica.version="${LIBERICA_VERSION}"

USER 10001:10001
WORKDIR /app
