# syntax=docker/dockerfile:1

# Liberica JRE 11 (JRE only, without JavaFX) on the chiselled Ubuntu 26.04 base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04
ARG LIBERICA_VERSION=11.0.33.1+5
ARG LIBERICA_SHA256=9f1a3fde1239ddbf2773ec7cf648ce9669fadf062bfa0ec3be30f72d5428ccba

FROM ubuntu:26.04 AS liberica

ARG LIBERICA_VERSION
ARG LIBERICA_SHA256

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

RUN url="https://github.com/bell-sw/Liberica/releases/download/${LIBERICA_VERSION}/bellsoft-jre${LIBERICA_VERSION}-linux-amd64.tar.gz" \
    && curl -fsSL -o /tmp/liberica.tar.gz "${url}" \
    && echo "${LIBERICA_SHA256}  /tmp/liberica.tar.gz" | sha256sum -c - \
    && mkdir -p /opt/java/openjdk \
    && tar -xzf /tmp/liberica.tar.gz -C /opt/java/openjdk --strip-components=1 \
    && rm -f /tmp/liberica.tar.gz \
    && /opt/java/openjdk/bin/java -version

FROM ${BASE_IMAGE}

ARG LIBERICA_VERSION

COPY --from=liberica /opt/java/openjdk /opt/java/openjdk

ENV JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Java 11 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Liberica JRE 11 on a minimal chiselled Ubuntu 26.04 base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="GPL-2.0-only WITH Classpath-exception-2.0" \
      org.opencontainers.image.version="${LIBERICA_VERSION}" \
      com.bellsoft.liberica.version="${LIBERICA_VERSION}"

USER 10001:10001
WORKDIR /app
