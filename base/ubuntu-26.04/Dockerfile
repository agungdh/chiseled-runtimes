# syntax=docker/dockerfile:1

# Minimal, chiselled Ubuntu 26.04 base for JVM runtimes.
# Only the files required by a (headless) JVM are shipped; there is no shell
# and no package manager in the final image.
FROM ubuntu:26.04 AS builder

ARG TARGETARCH
ARG CHISEL_VERSION=v1.5.1

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

# Cut a minimal root filesystem. Slices cover the JVM itself (glibc + C.UTF-8
# locale, libgcc, libstdc++, zlib), font support for AWT/PDF workloads, CA
# certificates and timezone data.
RUN mkdir -p /rootfs \
    && chisel cut --release ubuntu-26.04 --root /rootfs \
        base-files_base \
        base-files_release-info \
        base-passwd_data \
        ca-certificates_data \
        libc6_libs \
        libc-bin_locale \
        libgcc-s1_libs \
        libstdc++6_libs \
        zlib1g_libs \
        libfreetype6_libs \
        libfontconfig1_libs \
        fontconfig-config_config \
        tzdata_zoneinfo

# Non-root runtime user (uid/gid 10001), a writable /app and /tmp, and a
# minimal nsswitch.conf so glibc resolves hosts without warnings.
RUN printf '%s\n' \
        'app:x:10001:10001:Liberica runtime:/app:/sbin/nologin' \
        >> /rootfs/etc/passwd \
    && printf '%s\n' 'app:x:10001:' >> /rootfs/etc/group \
    && install -d -m 0755 -o 10001 -g 10001 /rootfs/app \
    && chmod 1777 /rootfs/tmp \
    && printf '%s\n' \
        'passwd: files' \
        'group: files' \
        'hosts: files dns' \
        > /rootfs/etc/nsswitch.conf

FROM scratch

COPY --from=builder /rootfs/ /

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LABEL org.opencontainers.image.title="chiseled-runtimes base (Ubuntu 26.04)" \
      org.opencontainers.image.description="Minimal chiselled Ubuntu 26.04 base image for JVM runtimes" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT"
