# syntax=docker/dockerfile:1

# Liberica JRE 8 (JRE only, without JavaFX) on the chiselled Ubuntu 26.04 base.
# Versions and checksums are pinned for reproducible builds; bump them together.
ARG BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04
ARG CHISEL_VERSION=v1.5.1
ARG LIBERICA_VERSION=8u514+5
ARG LIBERICA_SHA256_AMD64=3b4a7e6f61eb888c6de85592f1e14e27ba5d016cec7394afc9f94715f1c6f09e
ARG LIBERICA_SHA256_ARM64=016169611824d535db4790e250ceab7de74daf0adda6fed0e67fc02f94658246

# Shared, runtime-agnostic base. Java-only libraries are added below so other
# runtimes (Node.js, ...) never inherit fonts or zlib they do not use.
FROM ${BASE_IMAGE} AS common

FROM ubuntu:26.04 AS builder

ARG TARGETARCH
ARG CHISEL_VERSION
ARG LIBERICA_VERSION
ARG LIBERICA_SHA256_AMD64
ARG LIBERICA_SHA256_ARM64

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

# Seed the rootfs with the shared base, then add Java-only slices: zlib, font
# support for AWT/PDF workloads and libgcc (Java 8 links libgcc_s). Chisel
# overwrites existing files, so the final image does not carry duplicate copies
# of the shared base.
COPY --from=common / /rootfs

RUN chisel cut --release ubuntu-26.04 --root /rootfs \
        zlib1g_libs \
        libfreetype6_libs \
        libfontconfig1_libs \
        fontconfig-config_config \
        libgcc-s1_libs

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

FROM scratch

COPY --from=builder /rootfs/ /
COPY --from=builder /opt/java/openjdk /opt/java/openjdk

ARG LIBERICA_VERSION

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes Java 8 (Ubuntu 26.04)" \
      org.opencontainers.image.description="Liberica JRE 8 on a minimal chiselled Ubuntu 26.04 base" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="GPL-2.0-only WITH Classpath-exception-2.0" \
      org.opencontainers.image.version="${LIBERICA_VERSION}" \
      com.bellsoft.liberica.version="${LIBERICA_VERSION}"

USER 10001:10001
WORKDIR /app
