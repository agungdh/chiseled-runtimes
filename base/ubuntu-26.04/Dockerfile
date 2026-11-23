# syntax=docker/dockerfile:1

# Minimal, chiselled Ubuntu 26.04 base shared by all runtimes.
# Only runtime-agnostic files are shipped here; there is no shell and no
# package manager in the final image. Runtime-specific packages are added by
# each runtime image (for example fonts/zlib for Java, env/libatomic/libstdc++
# for Node.js).
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

# Cut a minimal root filesystem. Slices cover only runtime-agnostic files:
# glibc + C.UTF-8 locale, CA certificates and timezone data. Compiler runtimes
# (libgcc, libstdc++) are added by the images that actually link against them.
RUN mkdir -p /rootfs \
    && chisel cut --release ubuntu-26.04 --root /rootfs \
        base-files_base \
        base-files_release-info \
        base-passwd_data \
        ca-certificates_data \
        libc6_libs \
        libc-bin_locale \
        tzdata_zoneinfo

# Non-root runtime user (uid/gid 10001), a writable /app and /tmp, and a
# minimal nsswitch.conf so glibc resolves hosts without warnings.
RUN printf '%s\n' \
        'app:x:10001:10001:runtime:/app:/sbin/nologin' \
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
      org.opencontainers.image.description="Minimal chiselled Ubuntu 26.04 base image shared by all runtimes" \
      org.opencontainers.image.source="https://github.com/agungdh/chiseled-runtimes" \
      org.opencontainers.image.licenses="MIT"
