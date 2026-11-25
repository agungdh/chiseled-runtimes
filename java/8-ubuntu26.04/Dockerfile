# syntax=docker/dockerfile:1

# Liberica JRE 8 (JRE only, without JavaFX) on the chiselled Ubuntu 26.04 Java base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:java-ubuntu-26.04
ARG LIBERICA_VERSION=8u513+9
ARG LIBERICA_SHA256_AMD64=f188847b0ef508755df0106535613d176165c64d1ca4530e83d5a5a20a7a890c
ARG LIBERICA_SHA256_ARM64=08a756480e2a6f9353cf6fbc06119fba137264fe8c756ab5b3139c5b09906a7d

# Java 8 is the only Java version here that links against libgcc_s. The Java
# base leaves it out so Java 11+ stay free of it.
FROM ubuntu:26.04 AS extra

RUN mkdir -p /out \
    && cp -a --parents /usr/lib/*-linux-*/libgcc_s.so.1 /out/

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

COPY --from=extra /out/ /
COPY --from=jre /opt/java/openjdk /opt/java/openjdk

ARG LIBERICA_VERSION

ENV JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Java 8 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Liberica JRE 8 on a minimal chiselled Ubuntu 26.04 Java base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="GPL-2.0-only WITH Classpath-exception-2.0" \
      org.opencontainers.image.version="${LIBERICA_VERSION}" \
      com.bellsoft.liberica.version="${LIBERICA_VERSION}"

USER 10001:10001
WORKDIR /app
