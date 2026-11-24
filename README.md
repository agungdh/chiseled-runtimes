# chiseled-runtimes

"Chiselled" container images (minimal, shell-less) for multiple runtimes, built
on [Ubuntu](https://ubuntu.com/) + [chisel](https://github.com/canonical/chisel)
from Canonical.

Three runtimes are currently available:

- **Java** with the **[BellSoft Liberica](https://bell-sw.com/liberica-jdk/)** distribution.
- **Node.js** with the official binaries from [nodejs.org](https://nodejs.org/): LTS
  versions on Ubuntu 26.04, plus a non-LTS version (Node.js 25) on Ubuntu 26.10.
- **Bun** with the official binaries from [bun.sh](https://bun.sh/). Bun has no
  non-LTS track, so all of its versions use Ubuntu 26.04 LTS.

Images are layered in three tiers: **common base** (`base/ubuntu-*`) →
**language base** (`base/java-ubuntu-*`, `base/nodejs-ubuntu-*`,
`base/bun-ubuntu-*`) → **runtime image** (`java/*`, `nodejs/*`, `bun/*`). Each
layer only ships the files that are actually shared by the layers above it.

Other runtimes (`php`, etc.) will follow using the same pattern.

All images are available for **linux/amd64** and **linux/arm64** as a single
multi-arch manifest under the same tags.

## Available images

| Image | Runtime | Base | Architecture | Notes |
|---|---|---|---|---|
| `ghcr.io/agungdh/chiseled-runtimes/java:8-ubuntu26.04` | Liberica JRE 8 | Ubuntu 26.04 | amd64, arm64 | LTS, also available as `:8` |
| `ghcr.io/agungdh/chiseled-runtimes/java:11-ubuntu26.04` | Liberica JRE 11 | Ubuntu 26.04 | amd64, arm64 | LTS, also available as `:11` |
| `ghcr.io/agungdh/chiseled-runtimes/java:17-ubuntu26.04` | Liberica JRE 17 | Ubuntu 26.04 | amd64, arm64 | LTS, also available as `:17` |
| `ghcr.io/agungdh/chiseled-runtimes/java:21-ubuntu26.04` | Liberica JRE 21 | Ubuntu 26.04 | amd64, arm64 | LTS, also available as `:21` |
| `ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04` | Liberica JRE 25 | Ubuntu 26.04 | amd64, arm64 | LTS, also available as `:25` and `:latest` |
| `ghcr.io/agungdh/chiseled-runtimes/java:27-ubuntu26.10` | Liberica JRE 27 | Ubuntu 26.10 | amd64, arm64 | also available as `:27` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:18-ubuntu26.04` | Node.js 18 | Ubuntu 26.04 | amd64, arm64 | LTS (EOL), also available as `:18` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:20-ubuntu26.04` | Node.js 20 | Ubuntu 26.04 | amd64, arm64 | LTS (EOL), also available as `:20` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:22-ubuntu26.04` | Node.js 22 | Ubuntu 26.04 | amd64, arm64 | LTS, also available as `:22` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:24-ubuntu26.04` | Node.js 24 | Ubuntu 26.04 | amd64, arm64 | LTS, also available as `:24` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:25-ubuntu26.10` | Node.js 25 | Ubuntu 26.10 | amd64, arm64 | non-LTS (EOL), also available as `:25` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:26-ubuntu26.04` | Node.js 26 | Ubuntu 26.04 | amd64, arm64 | LTS, also available as `:26` and `:latest` |
| `ghcr.io/agungdh/chiseled-runtimes/bun:1-ubuntu26.04` | Bun 1 | Ubuntu 26.04 | amd64, arm64 | stable, also available as `:1` and `:latest` |
| `ghcr.io/agungdh/chiseled-runtimes/base:java-ubuntu-26.04` | Java base | Ubuntu 26.04 | amd64, arm64 | fonts + zlib for Java 8–25 |
| `ghcr.io/agungdh/chiseled-runtimes/base:java-ubuntu-26.10` | Java base | Ubuntu 26.10 | amd64, arm64 | fonts + zlib for Java 27 |
| `ghcr.io/agungdh/chiseled-runtimes/base:nodejs-ubuntu-26.04` | Node.js base | Ubuntu 26.04 | amd64, arm64 | env + libstdc++ + libgcc for Node.js 18, 20, 22, 24, 26 |
| `ghcr.io/agungdh/chiseled-runtimes/base:nodejs-ubuntu-26.10` | Node.js base | Ubuntu 26.10 | amd64, arm64 | env + libstdc++ + libgcc for Node.js 25 |
| `ghcr.io/agungdh/chiseled-runtimes/base:bun-ubuntu-26.04` | Bun base | Ubuntu 26.04 | amd64, arm64 | env for Bun |
| `ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04` | - | Ubuntu 26.04 | amd64, arm64 | common base without a runtime |
| `ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.10` | - | Ubuntu 26.10 | amd64, arm64 | common base without a runtime |

Java image characteristics:

- Multi-arch: Docker automatically picks `amd64` or `arm64` to match the host.
- Contains only a **JRE** (not a JDK), without JavaFX.
- The Liberica JRE bundle ships no headers, man pages, demos, samples, or
  `src.zip`. `LICENSE`, `legal/`, and `readme.txt` from BellSoft are still
  included. The Client VM (`lib/client`) is deliberately kept so that
  `java -client` stays compatible, even though the default is the Server VM.
- Runs as the non-root user `app` (uid/gid `10001`), `WORKDIR /app`.
- `JAVA_HOME=/opt/java/openjdk`, and `PATH` already points to `java`.
- No shell, no package manager (distroless-style).
- Fonts (DejaVu + fontconfig) needed for AWT/PDF are provided by
  `base:java-ubuntu-*`. CA certificates and timezone data are not included;
  Java uses its own `lib/security/cacerts` and `lib/tzdb.dat`.
- No default `ENTRYPOINT`/`CMD`, so it is free to use for any application.

Node.js image characteristics:

- Multi-arch: Docker automatically picks `amd64` or `arm64` to match the host.
- Contains the official Node.js binaries (`node`, `npm`, `npx`, and `corepack`
  when available in that release). Headers, changelogs, documentation, and man
  pages are stripped; the `LICENSE` file is still included.
- `/usr/bin/env`, `libstdc++`, and `libgcc_s` are provided by the Node.js
  language base (`base:nodejs-ubuntu-26.04` for LTS, `base:nodejs-ubuntu-26.10`
  for Node.js 25). `libatomic` is only added by Node.js 25 and 26, the two
  versions that link against it.
- Runs as the non-root user `app` (uid/gid `10001`), `WORKDIR /app`,
  `HOME=/app`.
- `NODE_VERSION` is set, and `PATH` already points to `node`/`npm`/`npx`.
- No shell, no package manager (distroless-style). Application dependencies
  must be installed in a builder stage (see the example below).
- CA certificates and timezone data are not included; Node.js uses its own root
  CA bundle and timezone data (ICU).
- No default `ENTRYPOINT`/`CMD`, so it is free to use for any application.

Bun image characteristics:

- Multi-arch: Docker automatically picks `amd64` or `arm64` to match the host.
- Contains a single official Bun binary, complete with its built-in package
  manager, bundler, transpiler, and test runner. `bunx` is used via `bun x`;
  there is no separate binary.
- The Bun binary only links against glibc (`libc`, `libpthread`, `libdl`,
  `libm`), so all of its runtime dependencies are already covered by the
  common base. The Bun base only adds `/usr/bin/env` so that the
  `#!/usr/bin/env bun` shebang keeps working. `libstdc++`, `libatomic`, and
  `libgcc_s` are not included because the Bun binary does not need them.
- Runs as the non-root user `app` (uid/gid `10001`), `WORKDIR /app`,
  `HOME=/app`.
- `BUN_VERSION` is set, and `PATH` already points to `bun`.
- No shell, no package manager (distroless-style). Application dependencies
  must be installed in a builder stage. `bun install` in the final image can
  still download packages, but lifecycle scripts that invoke `/bin/sh` will not
  run.
- CA certificates and timezone data are not included; Bun uses its own root CA
  bundle and timezone data.
- No default `ENTRYPOINT`/`CMD`, so it is free to use for any application.

Runtime dependency separation:

- `base/ubuntu-*` is the **common base**: glibc + the `C.UTF-8` locale,
  base-files, base-passwd, the `app` user, `/app`, and `/tmp`. There are no
  compiler libraries, fonts, CA certificates, or timezone data here.
- `base/java-ubuntu-*` is the **Java base**: adds `libfreetype6`,
  `libfontconfig1`, and the DejaVu fonts. zlib comes along as a freetype
  dependency, so every Java version uses it. Java 8 adds `libgcc_s` itself
  because it is the only version that links against it.
- `base/nodejs-ubuntu-26.04` (LTS) and `base/nodejs-ubuntu-26.10` (non-LTS)
  are the **Node.js base**: adds `/usr/bin/env`, `libstdc++`, and `libgcc_s`.
  Node.js 25 and 26 add `libatomic` themselves because they are the only two
  versions that link against it.
- `base/bun-ubuntu-26.04` is the **Bun base**: it only adds `/usr/bin/env`; the
  glibc that Bun needs is already in the common base.
- As a result, Java images ship no Node.js/Bun dependencies, Node.js/Bun
  images ship no Java fonts/zlib, and no version ships a library it does not
  use.

If an application needs system CA certificates or named timezones from native
libraries, add them yourself in a builder stage:

```dockerfile
FROM ubuntu:26.04 AS extra
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*

FROM ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04
COPY --from=extra /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=extra /usr/share/zoneinfo /usr/share/zoneinfo
```

Java, Node.js, and Bun themselves do not need them: all three use their built-in
stores.

## How the base layers work

The language base does not copy the contents of the common base straight into
the final image. The pattern is:

1. `FROM ${COMMON_BASE_IMAGE} AS common` — the common base is used as a seed.
2. `FROM ubuntu:<release> AS builder` — a stage with apt + chisel.
3. `COPY --from=common / /rootfs` — the contents of the common base go into the rootfs.
4. `chisel cut --release ubuntu-<release> --root /rootfs <slice...>` — the
   language-specific slices are added; chisel overwrites existing files so
   there are no duplicates.
5. `FROM scratch` + `COPY --from=builder /rootfs/ /` — the final image only
   contains the cut rootfs, without apt/chisel.
6. `ENV` (`LANG`, `LC_ALL`, `TZ`, `PATH`) is redeclared because
   `FROM scratch` does not inherit ENV from the common base.

Do not copy `/out/` from the `chisel cut` output straight into the final image
without seeding the common base: slices such as `libc6_libs` will duplicate
glibc.

Dependencies used by only some versions are added in that version's Dockerfile
through an `extra` stage, not in the language base:

| Version | Addition | Reason |
|---|---|---|
| Java 8 | `libgcc_s.so.1` | only Java 8 links against it |
| Java 11/17/21/25/27 | - | already covered by the Java base |
| Node.js 18/20/22/24 | - | already covered by the Node.js base |
| Node.js 25/26 | `libatomic.so.1` | only those two versions link against it |
| Bun 1 | - | already covered by the Bun base + common base |

The `node`/`jre` builder stages also need those libraries in order to run
`node --version` / `java -version`. That is why `libatomic1` is installed in
the Node 25/26 builder stage; what gets copied into the final image is still
only the `.so` file from the `extra` stage. The `bun` builder stage needs no
additions because the Bun binary only links against glibc.

Checklist for adding a version/runtime:

1. Create `<runtime>/<version>-ubuntu<release>/Dockerfile` with
   `ARG BASE_IMAGE=.../base:<runtime>-ubuntu-<release>`.
2. Put dependencies used by all versions in
   `base/<runtime>-ubuntu-<release>/Dockerfile`; put version-specific
   dependencies in that version's Dockerfile `extra` stage.
3. For a new runtime, create its language base (seed → chisel → scratch
   pattern) and `scripts/smoke/<runtime>.sh`.
4. Update the image/tag/structure tables in the README and `LATEST_TARGETS` if
   needed.

Every Dockerfile accepts `--build-arg TARGETARCH=amd64|arm64` to select the
chisel, Node.js, Bun, and Liberica binaries. CI and `scripts/build-local.sh`
always pass it. Before adding a slice/extra, check the binary's dependencies
with `readelf -d <binary> | grep NEEDED`.

## Usage

Run a JAR:

```dockerfile
FROM ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04

COPY --chown=10001:10001 app.jar /app/app.jar

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

Or directly from the CLI:

```bash
docker run --rm ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04 java -version
```

Example with a Spring Boot application:

```bash
docker run --rm -p 8080:8080 \
  -v "$PWD/app.jar:/app/app.jar:ro" \
  ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04 \
  java -jar /app/app.jar
```

For Node.js, install dependencies in a builder stage because the final image
has no shell (`RUN` commands cannot be used on top of this image):

```dockerfile
FROM node:26-bookworm-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

FROM ghcr.io/agungdh/chiseled-runtimes/nodejs:26-ubuntu26.04
COPY --from=build --chown=10001:10001 /app /app
ENV NODE_ENV=production
CMD ["node", "server.js"]
```

Or directly from the CLI:

```bash
docker run --rm ghcr.io/agungdh/chiseled-runtimes/nodejs:26-ubuntu26.04 node --version
docker run --rm ghcr.io/agungdh/chiseled-runtimes/nodejs:26-ubuntu26.04 npm --version
```

For Bun, install dependencies in a builder stage for the same reason:

```dockerfile
FROM oven/bun:1 AS build
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production
COPY . .

FROM ghcr.io/agungdh/chiseled-runtimes/bun:1-ubuntu26.04
COPY --from=build --chown=10001:10001 /app /app
ENV NODE_ENV=production
CMD ["bun", "server.ts"]
```

Or directly from the CLI:

```bash
docker run --rm ghcr.io/agungdh/chiseled-runtimes/bun:1-ubuntu26.04 bun --version
docker run --rm ghcr.io/agungdh/chiseled-runtimes/bun:1-ubuntu26.04 bun -e 'console.log(Bun.version)'
```

## Tags and versioning

Every image has two kinds of tags:

**1. Channel tags (moving / mutable)** — the ones you should use in
`FROM`/compose. They change whenever there is a runtime patch or a base update:

| Tag | Contents |
|---|---|
| `java:8-ubuntu26.04` | latest Java 8 on Ubuntu 26.04 (specific target, multi-arch) |
| `java:8` | latest Java 8 (across bases, currently Ubuntu 26.04, multi-arch) |
| `java:11-ubuntu26.04` | latest Java 11 on Ubuntu 26.04 (specific target, multi-arch) |
| `java:11` | latest Java 11 (across bases, currently Ubuntu 26.04, multi-arch) |
| `java:17-ubuntu26.04` | latest Java 17 on Ubuntu 26.04 (specific target, multi-arch) |
| `java:17` | latest Java 17 (across bases, currently Ubuntu 26.04, multi-arch) |
| `java:21-ubuntu26.04` | latest Java 21 on Ubuntu 26.04 (specific target, multi-arch) |
| `java:21` | latest Java 21 (across bases, currently Ubuntu 26.04, multi-arch) |
| `java:25-ubuntu26.04` | latest Java 25 on Ubuntu 26.04 (specific target, multi-arch) |
| `java:25` | latest Java 25 (across bases, currently Ubuntu 26.04, multi-arch) |
| `java:27-ubuntu26.10` | latest Java 27 on Ubuntu 26.10 (specific target, multi-arch) |
| `java:27` | latest Java 27 (across bases, currently Ubuntu 26.10, multi-arch) |
| `java:latest` | the target listed in `LATEST_TARGETS` (currently Java 25, multi-arch) |
| `nodejs:18-ubuntu26.04` | latest Node.js 18 on Ubuntu 26.04 (specific target, multi-arch) |
| `nodejs:18` | latest Node.js 18 (across bases, currently Ubuntu 26.04, multi-arch) |
| `nodejs:20-ubuntu26.04` | latest Node.js 20 on Ubuntu 26.04 (specific target, multi-arch) |
| `nodejs:20` | latest Node.js 20 (across bases, currently Ubuntu 26.04, multi-arch) |
| `nodejs:22-ubuntu26.04` | latest Node.js 22 on Ubuntu 26.04 (specific target, multi-arch) |
| `nodejs:22` | latest Node.js 22 (across bases, currently Ubuntu 26.04, multi-arch) |
| `nodejs:24-ubuntu26.04` | latest Node.js 24 on Ubuntu 26.04 (specific target, multi-arch) |
| `nodejs:24` | latest Node.js 24 (across bases, currently Ubuntu 26.04, multi-arch) |
| `nodejs:25-ubuntu26.10` | latest Node.js 25 on Ubuntu 26.10 (specific target, multi-arch) |
| `nodejs:25` | latest Node.js 25 (across bases, currently Ubuntu 26.10, multi-arch) |
| `nodejs:26-ubuntu26.04` | latest Node.js 26 on Ubuntu 26.04 (specific target, multi-arch) |
| `nodejs:26` | latest Node.js 26 (across bases, currently Ubuntu 26.04, multi-arch) |
| `nodejs:latest` | the target listed in `LATEST_TARGETS` (currently Node.js 26, multi-arch) |
| `bun:1-ubuntu26.04` | latest Bun 1 on Ubuntu 26.04 (specific target, multi-arch) |
| `bun:1` | latest Bun 1 (across bases, currently Ubuntu 26.04, multi-arch) |
| `bun:latest` | the target listed in `LATEST_TARGETS` (currently Bun 1, multi-arch) |
| `base:java-ubuntu-26.04` | latest Java base on Ubuntu 26.04 (multi-arch) |
| `base:java-ubuntu-26.10` | latest Java base on Ubuntu 26.10 (multi-arch) |
| `base:nodejs-ubuntu-26.04` | latest Node.js base on Ubuntu 26.04 (multi-arch) |
| `base:nodejs-ubuntu-26.10` | latest Node.js base on Ubuntu 26.10 (multi-arch) |
| `base:bun-ubuntu-26.04` | latest Bun base on Ubuntu 26.04 (multi-arch) |
| `base:ubuntu-26.04` | latest Ubuntu 26.04 common base (multi-arch) |
| `base:ubuntu-26.10` | latest Ubuntu 26.10 common base (multi-arch) |

Each architecture can still be pinned explicitly when needed:

```
java:25-ubuntu26.04-amd64
java:25-ubuntu26.04-arm64
nodejs:25-ubuntu26.10-amd64
nodejs:25-ubuntu26.10-arm64
nodejs:26-ubuntu26.04-amd64
nodejs:26-ubuntu26.04-arm64
bun:1-ubuntu26.04-amd64
bun:1-ubuntu26.04-arm64
base:java-ubuntu-26.04-amd64
base:java-ubuntu-26.04-arm64
base:nodejs-ubuntu-26.04-amd64
base:nodejs-ubuntu-26.04-arm64
base:nodejs-ubuntu-26.10-amd64
base:nodejs-ubuntu-26.10-arm64
base:bun-ubuntu-26.04-amd64
base:bun-ubuntu-26.04-arm64
base:ubuntu-26.04-amd64
base:ubuntu-26.04-arm64
base:ubuntu-26.10-amd64
base:ubuntu-26.10-arm64
```

Channel tags such as `java:25`, `nodejs:26`, `bun:1`, and `:latest` are
manifest lists that contain both architectures. The `os`/`architecture` fields
inside the manifest automatically follow each runner's build, so no QEMU or
cross-arch build is needed.

**2. Build tags (for audit/rollback)** — point at one specific build:

```
java:25-ubuntu26.04-<full git sha>-<YYYYMMDDHHMMSS>
java:25-ubuntu26.04-<full git sha>-<YYYYMMDDHHMMSS>-amd64
java:25-ubuntu26.04-<full git sha>-<YYYYMMDDHHMMSS>-arm64
nodejs:26-ubuntu26.04-<full git sha>-<YYYYMMDDHHMMSS>
nodejs:26-ubuntu26.04-<full git sha>-<YYYYMMDDHHMMSS>-amd64
nodejs:26-ubuntu26.04-<full git sha>-<YYYYMMDDHHMMSS>-arm64
bun:1-ubuntu26.04-<full git sha>-<YYYYMMDDHHMMSS>
bun:1-ubuntu26.04-<full git sha>-<YYYYMMDDHHMMSS>-amd64
bun:1-ubuntu26.04-<full git sha>-<YYYYMMDDHHMMSS>-arm64
base:java-ubuntu-26.04-<full git sha>-<YYYYMMDDHHMMSS>
base:nodejs-ubuntu-26.04-<full git sha>-<YYYYMMDDHHMMSS>
base:nodejs-ubuntu-26.10-<full git sha>-<YYYYMMDDHHMMSS>
base:bun-ubuntu-26.04-<full git sha>-<YYYYMMDDHHMMSS>
base:ubuntu-26.04-<full git sha>-<YYYYMMDDHHMMSS>
base:ubuntu-26.10-<full git sha>-<YYYYMMDDHHMMSS>
```

The SHA is deliberately full (40 characters) to avoid ambiguity; the build
stamp keeps tags unique even when the same commit is rebuilt (for example an
Ubuntu base update or a re-run workflow).

Because any tag can still be overwritten (GHCR does not enforce immutability),
full reproducibility only comes from the **digest**. After a push, CI prints the
digest of every tag in the job summary:

```
ghcr.io/agungdh/chiseled-runtimes/java@sha256:...
```

Images are also given the OCI labels `org.opencontainers.image.revision` (full
SHA) and `org.opencontainers.image.created`.

In practice:

- Dev/staging: use channel tags (`java:25`) so you always get patches.
- Production that needs reproducibility: pin the digest, then update it via
  Renovate/Dependabot in the form `java:25-ubuntu26.04@sha256:...`.
- Old builds: use build tags for rollback/audit.

## Local build

Requires Docker (BuildKit). With no arguments, the script builds all bases and
then all runtimes, runs the smoke tests, and (optionally) pushes. The default
is `linux/amd64` only; add `PLATFORMS` for arm64.

```bash
./scripts/build-local.sh

# build + push to the registry (per-arch tags, then merge into multi-arch)
PUSH=true ./scripts/build-local.sh

# amd64 + arm64 (cross-building arm64 on an amd64 host needs QEMU/binfmt)
PLATFORMS="linux/amd64 linux/arm64" ./scripts/build-local.sh

# override registry/owner
REGISTRY=ghcr.io OWNER=agungdh ./scripts/build-local.sh

# override the git revision recorded in labels/tags
REVISION="$(git rev-parse HEAD)" PUSH=true ./scripts/build-local.sh
```

With `PUSH=true`, each architecture is pushed as `<tag>-amd64` / `<tag>-arm64`,
then `docker buildx imagetools` creates a multi-arch manifest for the channel
tags (`<tag>`, `<version>`, `:latest`). So `:latest` and the other tags
automatically point at both architectures.

You can also build only specific targets. Base dependencies are built
automatically (common base → language base → runtime):

```bash
# only Java 27 (common 26.10 + Java base 26.10 built as dependencies)
./scripts/build-local.sh java/27-ubuntu26.10

# only Java 21 (common 26.04 + Java base 26.04 built as dependencies)
./scripts/build-local.sh java/21-ubuntu26.04

# only Node.js 26 (common 26.04 + Node.js base built as dependencies)
./scripts/build-local.sh nodejs/26-ubuntu26.04

# only Node.js 25 (common 26.10 + Node.js base 26.10 built as dependencies)
./scripts/build-local.sh nodejs/25-ubuntu26.10

# only Bun 1 (common 26.04 + Bun base built as dependencies)
./scripts/build-local.sh bun/1-ubuntu26.04

# only common base 26.10
./scripts/build-local.sh base/ubuntu-26.10

# only Java base 26.04 (common 26.04 built as a dependency)
./scripts/build-local.sh base/java-ubuntu-26.04

# several targets at once
./scripts/build-local.sh base/java-ubuntu-26.04 java/25-ubuntu26.04 nodejs/26-ubuntu26.04 bun/1-ubuntu26.04
```

Manual builds:

```bash
docker build -t ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04 base/ubuntu-26.04

docker build \
  --build-arg COMMON_BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04 \
  -t ghcr.io/agungdh/chiseled-runtimes/base:java-ubuntu-26.04 \
  base/java-ubuntu-26.04

docker build \
  --build-arg BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:java-ubuntu-26.04 \
  -t ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04 \
  java/25-ubuntu26.04

docker build \
  --build-arg BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:nodejs-ubuntu-26.04 \
  -t ghcr.io/agungdh/chiseled-runtimes/nodejs:26-ubuntu26.04 \
  nodejs/26-ubuntu26.04

docker build \
  --build-arg BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:nodejs-ubuntu-26.10 \
  -t ghcr.io/agungdh/chiseled-runtimes/nodejs:25-ubuntu26.10 \
  nodejs/25-ubuntu26.10

docker build \
  --build-arg COMMON_BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04 \
  -t ghcr.io/agungdh/chiseled-runtimes/base:bun-ubuntu-26.04 \
  base/bun-ubuntu-26.04

docker build \
  --build-arg BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:bun-ubuntu-26.04 \
  -t ghcr.io/agungdh/chiseled-runtimes/bun:1-ubuntu26.04 \
  bun/1-ubuntu26.04
```

## Structure

```
.
├── .github/workflows/build.yml       # CI: detect, build per-arch, merge, push
├── base/
│   ├── ubuntu-26.04/Dockerfile         # common base (chisel -> scratch)
│   ├── ubuntu-26.10/Dockerfile
│   ├── java-ubuntu-26.04/Dockerfile    # Java base (fonts + zlib)
│   ├── java-ubuntu-26.10/Dockerfile
│   ├── nodejs-ubuntu-26.04/Dockerfile  # Node.js base LTS (env + libstdc++ + libgcc)
│   ├── nodejs-ubuntu-26.10/Dockerfile  # Node.js base non-LTS
│   └── bun-ubuntu-26.04/Dockerfile     # Bun base (env)
├── java/
│   ├── 8-ubuntu26.04/Dockerfile      # Liberica JRE 8
│   ├── 11-ubuntu26.04/Dockerfile     # Liberica JRE 11
│   ├── 17-ubuntu26.04/Dockerfile     # Liberica JRE 17
│   ├── 21-ubuntu26.04/Dockerfile     # Liberica JRE 21
│   ├── 25-ubuntu26.04/Dockerfile     # Liberica JRE 25
│   └── 27-ubuntu26.10/Dockerfile     # Liberica JRE 27
├── nodejs/
│   ├── 18-ubuntu26.04/Dockerfile     # Node.js 18 LTS
│   ├── 20-ubuntu26.04/Dockerfile     # Node.js 20 LTS
│   ├── 22-ubuntu26.04/Dockerfile     # Node.js 22 LTS
│   ├── 24-ubuntu26.04/Dockerfile     # Node.js 24 LTS
│   ├── 25-ubuntu26.10/Dockerfile     # Node.js 25 (non-LTS)
│   └── 26-ubuntu26.04/Dockerfile     # Node.js 26 LTS
├── bun/
│   └── 1-ubuntu26.04/Dockerfile      # Bun 1 (stable)
├── scripts/
│   ├── build-local.sh
│   ├── ci-detect-targets.py          # detect targets + expand the per-arch matrix
│   ├── merge-manifests.sh            # combine per-arch images into multi-arch
│   ├── push-image.sh                 # push many tags + report digests
│   └── smoke/
│       ├── bun.sh                    # per-runtime smoke test
│       ├── java.sh
│       └── nodejs.sh
└── README.md
```

## CI: selective multi-arch builds

The workflow does not use QEMU. The `changes` job scans the folders to find
targets, then expands each target into two native builds:

| Architecture | Runner | Platform |
|---|---|---|
| amd64 | `ubuntu-26.04` | `linux/amd64` |
| arm64 | `ubuntu-26.04-arm` | `linux/arm64` |

Once both builds finish, the `merge_base` / `merge_lang_base` /
`merge_runtime` jobs use `docker buildx imagetools create` to combine the
per-arch images into a single multi-arch manifest. The `os`/`architecture`
fields in the manifest are filled in automatically from each image, so channel
tags such as `:25`, `:1`, and `:latest` work directly on both amd64 and arm64.

Which targets get built stays selective:

- Change `java/27-ubuntu26.10/**` → only Java 27 is built.
- Change `java/25-ubuntu26.04/**` → only Java 25 is built.
- Change `java/21-ubuntu26.04/**` → only Java 21 is built.
- Change `java/17-ubuntu26.04/**` → only Java 17 is built.
- Change `java/11-ubuntu26.04/**` → only Java 11 is built.
- Change `java/8-ubuntu26.04/**` → only Java 8 is built.
- Change `nodejs/25-ubuntu26.10/**` → only Node.js 25 is built.
- Change `nodejs/26-ubuntu26.04/**` → only Node.js 26 is built.
- Change `nodejs/24-ubuntu26.04/**` → only Node.js 24 is built.
- Change `nodejs/22-ubuntu26.04/**` → only Node.js 22 is built.
- Change `nodejs/20-ubuntu26.04/**` → only Node.js 20 is built.
- Change `nodejs/18-ubuntu26.04/**` → only Node.js 18 is built.
- Change `bun/1-ubuntu26.04/**` → only Bun 1 is built.
- Change `base/java-ubuntu-26.04/**` → Java base 26.04 + Java 8, 11, 17, 21, 25.
- Change `base/java-ubuntu-26.10/**` → Java base 26.10 + Java 27.
- Change `base/nodejs-ubuntu-26.04/**` → Node.js base 26.04 + Node.js 18, 20,
  22, 24, 26.
- Change `base/nodejs-ubuntu-26.10/**` → Node.js base 26.10 + Node.js 25.
- Change `base/bun-ubuntu-26.04/**` → Bun base 26.04 + Bun 1.
- Change `base/ubuntu-26.04/**` → common base 26.04 + language base 26.04 +
  every runtime on that release (Java 8, 11, 17, 21, 25; Node.js 18, 20, 22,
  24, 26; and Bun 1), for both architectures.
- Change `base/ubuntu-26.10/**` → common base 26.10 + Java base 26.10 + Java 27
  + Node.js base 26.10 + Node.js 25.
- Change `.github/**` or `workflow_dispatch` → every target is built.
- Change `README.md` / `scripts/**` → no images are built.

New runtimes are detected automatically as long as they follow the folder
convention:

```
<runtime>/<version>-ubuntu<release>/Dockerfile
```

For example: `php/8.6-ubuntu26.04/Dockerfile`, `python/3.14-ubuntu26.04/Dockerfile`.
Also add `scripts/smoke/<runtime>.sh` (accepting the image and platform as
arguments) so it takes part in the smoke test. The `<version>` tag (e.g.
`:8.6`, `:3.14`) is created automatically; the `:latest` tag is only for
targets listed in `LATEST_TARGETS` in the workflow.

The actions in the workflow are deliberately pinned to the **latest major**
(`actions/checkout@v7`, `docker/login-action@v4`) so they do not trigger
deprecation warnings from the Node.js runtime bundled with GitHub Actions. When
GitHub announces a new deprecation, check the latest release of each action and
bump its major in `.github/workflows/build.yml`; no other actions are used (the
Docker build and `buildx imagetools` use the runner's built-in tools).

If a base is not yet in the registry (a PR, the first build, or a missing
package), CI builds the common base and then the language base locally on a
runner of the matching architecture before building the runtime. On a push to
`main`, each layer is pushed per-arch and its multi-arch manifest is created
before the next layer is built.

Every pushed image also gets a per-arch build tag
(`<tag>-<full sha>-<YYYYMMDDHHMMSS>-<arch>`), a combined build tag, a
multi-arch channel tag, and its digest printed in the job summary. Details are
in [Tags and versioning](#tags-and-versioning).

## Updating versions

### Java

The Liberica version and checksums are pinned in each `java/*/Dockerfile`
(`LIBERICA_VERSION`, `LIBERICA_SHA256_AMD64`, and `LIBERICA_SHA256_ARM64`).
To upgrade:

1. Get the latest version from the BellSoft API:
   `https://api.bell-sw.com/v1/liberica/releases?version-feature=25&os=linux&arch=x86&bitness=64&package-type=tar.gz`
2. Download the `jre` bundle for both architectures:
   `bellsoft-jre<VERSION>-linux-amd64.tar.gz` and
   `bellsoft-jre<VERSION>-linux-aarch64.tar.gz` (BellSoft uses `aarch64`
   for arm64), then compute the `sha256sum` of each.
3. Update `LIBERICA_SHA256_AMD64` and `LIBERICA_SHA256_ARM64`, rebuild
   (amd64 and arm64), then run the smoke test.

The arm64 checksum can also be taken directly from the `digest` field of the
asset in the BellSoft GitHub release.

### Node.js

The Node.js version and checksums are pinned in each `nodejs/*/Dockerfile`
(`NODE_VERSION`, `NODE_SHA256_AMD64`, and `NODE_SHA256_ARM64`). LTS versions
(even) use Ubuntu 26.04. Non-LTS versions (odd) use Ubuntu 26.10, the newest
Ubuntu release; currently only Node.js 25 is available. Node.js 18, 20, and 25
are EOL, but their images are still built as long as the target folder exists.
To upgrade:

1. Get the latest version from `https://nodejs.org/dist/index.json`. For LTS,
   pick the entry whose `lts` field is not `false`; for non-LTS (e.g. 25),
   pick the latest version with that major.
2. Download the official tarball for both architectures:
   `node-v<VERSION>-linux-x64.tar.xz` and
   `node-v<VERSION>-linux-arm64.tar.xz`.
3. Get the checksums from
   `https://nodejs.org/dist/v<VERSION>/SHASUMS256.txt`, then update
   `NODE_VERSION`, `NODE_SHA256_AMD64`, and `NODE_SHA256_ARM64`.
4. Rebuild (amd64 and arm64), then run the smoke test.

### Bun

Bun has no separate LTS/non-LTS track; all of its stable releases use Ubuntu
26.04 LTS. The Bun version and checksums are pinned in `bun/*/Dockerfile`
(`BUN_VERSION`, `BUN_SHA256_AMD64`, and `BUN_SHA256_ARM64`). To upgrade:

1. Get the latest stable release from
   `https://api.github.com/repos/oven-sh/bun/releases/latest` (the `tag_name`
   field, e.g. `bun-v1.4.5`).
2. Download the official zip for both architectures: `bun-linux-x64.zip` and
   `bun-linux-aarch64.zip` (Bun uses `aarch64` for arm64).
3. Get the checksums from `SHASUMS256.txt` in the same release, then update
   `BUN_VERSION`, `BUN_SHA256_AMD64`, and `BUN_SHA256_ARM64`.
4. Rebuild (amd64 and arm64), then run the smoke test.

## Size notes

The common base is about 5.7 MB (file bytes; roughly 10 MB as an uncompressed
image). The Java base is about 12.2 MB, the Node.js base about 8.7 MB, and the
Bun base is practically the same as the common base because it only adds
`/usr/bin/env`. Java images are about 390 MB because the Liberica JRE bundle
ships `lib/modules` and several CDS archives (`lib/**/*.jsa`), including the
Server and Client VMs. The Client VM is deliberately not removed so that
`java -client` stays compatible; removing it could save about 77 MB, while
removing only the Client VM CDS archives saves about 60 MB without disabling
`-client`. If you need something much smaller later, the option is to build a
custom runtime with `jlink` (for example
`--add-modules ALL-MODULE-PATH --strip-debug --no-man-pages`) in a builder
stage.

Node.js images are about 250 MB (uncompressed) because the official Node.js
binary alone is about 145 MB. From the official tarball, what gets removed is
`include/`, `share/` (man pages, gdb helper, systemtap), `CHANGELOG.md`,
`README.md`, and `lib/node_modules/npm/docs` and `lib/node_modules/npm/man`.
`npm` is still included so the image can be used to run applications and
tooling; the Node.js and npm `LICENSE` files are not removed.

Bun images are about 115 MB (uncompressed) because the official binary alone is
about 107 MB. The official Bun zip only contains the `bun` binary without
headers, documentation, or man pages, so there is nothing to strip.

## License

- The code and configuration in this repository: see the repository license.
- Liberica JRE: GPLv2 with the Classpath Exception. See
  [BellSoft Liberica](https://bell-sw.com/liberica-jdk/) for details.
- Node.js: MIT. The bundled `npm` is licensed under Artistic-2.0. See the
  [Node.js license](https://github.com/nodejs/node/blob/main/LICENSE) for details.
- Bun: MIT. The official binary also bundles third-party components (including
  JavaScriptCore). See the
  [Bun license](https://github.com/oven-sh/bun/blob/main/LICENSE.md) for details.
