# syntax=docker/dockerfile:1

# Liberica JRE 17 (JRE only, without JavaFX) on the chiselled Ubuntu 26.04 Java base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:java-ubuntu-26.04
ARG LIBERICA_VERSION=17.0.21.1+5
ARG LIBERICA_SHA256_AMD64=502d031e0c70daddb00062b63289f1c53d01164854b1873f84b06a22fb839a56
ARG LIBERICA_SHA256_ARM64=9896a18ed0fd5eade8c28fff04b411d6cff289f9f622bc32b4f892bdef4ce88a

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

LABEL org.opencontainers.image.title="chiseled-runtimes Java 17 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Liberica JRE 17 on a minimal chiselled Ubuntu 26.04 Java base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="GPL-2.0-only WITH Classpath-exception-2.0" \
      org.opencontainers.image.version="${LIBERICA_VERSION}" \
      com.bellsoft.liberica.version="${LIBERICA_VERSION}"

USER 10001:10001
WORKDIR /app
