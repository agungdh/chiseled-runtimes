# chiseled-runtimes

Image container "chiselled" (minimal, tanpa shell) untuk berbagai runtime, dibangun
di atas [Ubuntu](https://ubuntu.com/) + [chisel](https://github.com/canonical/chisel)
dari Canonical.

Saat ini tersedia dua runtime:

- **Java** dengan distribusi **[BellSoft Liberica](https://bell-sw.com/liberica-jdk/)**.
- **Node.js** dengan binary resmi dari [nodejs.org](https://nodejs.org/), hanya versi LTS.

Runtime lain (`php`, dst.) menyusul dengan pola yang sama.

Semua image tersedia untuk **linux/amd64** dan **linux/arm64** sebagai satu
manifest multi-arch dengan tag yang sama.

## Image yang tersedia

| Image | Runtime | Base | Arsitektur | Keterangan |
|---|---|---|---|---|
| `ghcr.io/agungdh/chiseled-runtimes/java:8-ubuntu26.04` | Liberica JRE 8 | Ubuntu 26.04 | amd64, arm64 | LTS, juga tersedia sebagai `:8` |
| `ghcr.io/agungdh/chiseled-runtimes/java:11-ubuntu26.04` | Liberica JRE 11 | Ubuntu 26.04 | amd64, arm64 | LTS, juga tersedia sebagai `:11` |
| `ghcr.io/agungdh/chiseled-runtimes/java:17-ubuntu26.04` | Liberica JRE 17 | Ubuntu 26.04 | amd64, arm64 | LTS, juga tersedia sebagai `:17` |
| `ghcr.io/agungdh/chiseled-runtimes/java:21-ubuntu26.04` | Liberica JRE 21 | Ubuntu 26.04 | amd64, arm64 | LTS, juga tersedia sebagai `:21` |
| `ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04` | Liberica JRE 25 | Ubuntu 26.04 | amd64, arm64 | LTS, juga tersedia sebagai `:25` dan `:latest` |
| `ghcr.io/agungdh/chiseled-runtimes/java:27-ubuntu26.10` | Liberica JRE 27 | Ubuntu 26.10 | amd64, arm64 | juga tersedia sebagai `:27` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:18-ubuntu26.04` | Node.js 18 | Ubuntu 26.04 | amd64, arm64 | LTS (EOL), juga tersedia sebagai `:18` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:20-ubuntu26.04` | Node.js 20 | Ubuntu 26.04 | amd64, arm64 | LTS (EOL), juga tersedia sebagai `:20` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:22-ubuntu26.04` | Node.js 22 | Ubuntu 26.04 | amd64, arm64 | LTS, juga tersedia sebagai `:22` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:24-ubuntu26.04` | Node.js 24 | Ubuntu 26.04 | amd64, arm64 | LTS, juga tersedia sebagai `:24` |
| `ghcr.io/agungdh/chiseled-runtimes/nodejs:26-ubuntu26.04` | Node.js 26 | Ubuntu 26.04 | amd64, arm64 | LTS, juga tersedia sebagai `:26` dan `:latest` |
| `ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04` | - | Ubuntu 26.04 | amd64, arm64 | base image tanpa runtime |
| `ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.10` | - | Ubuntu 26.10 | amd64, arm64 | base image tanpa runtime |

Karakteristik image Java:

- Multi-arch: Docker otomatis memilih `amd64` atau `arm64` sesuai host.
- Hanya berisi **JRE** (bukan JDK), tanpa JavaFX.
- Berjalan sebagai user non-root `app` (uid/gid `10001`), `WORKDIR /app`.
- `JAVA_HOME=/opt/java/openjdk`, `PATH` sudah menunjuk ke `java`.
- Tanpa shell, tanpa package manager (distroless-style).
- Sudah termasuk CA certificates, timezone data (`TZ=UTC`), dan font
  (DejaVu + fontconfig) untuk kebutuhan AWT/PDF.
- Tidak punya `ENTRYPOINT`/`CMD` default, jadi bebas dipakai untuk aplikasi apa pun.

Karakteristik image Node.js:

- Multi-arch: Docker otomatis memilih `amd64` atau `arm64` sesuai host.
- Berisi binary resmi Node.js (`node`, `npm`, `npx`, dan `corepack` bila tersedia
  di rilis tersebut). Header dan dokumentasi sudah dibuang.
- Membawa `/usr/bin/env` dan `libatomic` sendiri, jadi base image tetap bersih
  dari dependensi khusus Node.js.
- Berjalan sebagai user non-root `app` (uid/gid `10001`), `WORKDIR /app`,
  `HOME=/app`.
- `NODE_VERSION` di-set, `PATH` sudah menunjuk ke `node`/`npm`/`npx`.
- Tanpa shell, tanpa package manager (distroless-style). Dependency aplikasi
  harus di-install di stage builder (lihat contoh di bawah).
- Sudah termasuk CA certificates dan timezone data (`TZ=UTC`).
- Tidak punya `ENTRYPOINT`/`CMD` default, jadi bebas dipakai untuk aplikasi apa pun.

## Pemakaian

Jalankan JAR:

```dockerfile
FROM ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04

COPY --chown=10001:10001 app.jar /app/app.jar

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

Atau langsung dari CLI:

```bash
docker run --rm ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04 java -version
```

Contoh dengan aplikasi Spring Boot:

```bash
docker run --rm -p 8080:8080 \
  -v "$PWD/app.jar:/app/app.jar:ro" \
  ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04 \
  java -jar /app/app.jar
```

Untuk Node.js, install dependency di stage builder karena image final tidak
punya shell (perintah `RUN` tidak bisa dipakai di atas image ini):

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

Atau langsung dari CLI:

```bash
docker run --rm ghcr.io/agungdh/chiseled-runtimes/nodejs:26-ubuntu26.04 node --version
docker run --rm ghcr.io/agungdh/chiseled-runtimes/nodejs:26-ubuntu26.04 npm --version
```

## Tag dan versioning

Setiap image punya dua jenis tag:

**1. Channel tag (bergerak / mutable)** — yang sebaiknya dipakai di
`FROM`/compose. Tag ini ikut berubah saat ada patch runtime atau update base:

| Tag | Isi |
|---|---|
| `java:8-ubuntu26.04` | Java 8 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `java:8` | Java 8 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `java:11-ubuntu26.04` | Java 11 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `java:11` | Java 11 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `java:17-ubuntu26.04` | Java 17 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `java:17` | Java 17 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `java:21-ubuntu26.04` | Java 21 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `java:21` | Java 21 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `java:25-ubuntu26.04` | Java 25 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `java:25` | Java 25 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `java:latest` | target yang terdaftar di `LATEST_TARGETS` (saat ini Java 25, multi-arch) |
| `nodejs:18-ubuntu26.04` | Node.js 18 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `nodejs:18` | Node.js 18 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `nodejs:20-ubuntu26.04` | Node.js 20 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `nodejs:20` | Node.js 20 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `nodejs:22-ubuntu26.04` | Node.js 22 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `nodejs:22` | Node.js 22 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `nodejs:24-ubuntu26.04` | Node.js 24 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `nodejs:24` | Node.js 24 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `nodejs:26-ubuntu26.04` | Node.js 26 terbaru di Ubuntu 26.04 (target spesifik, multi-arch) |
| `nodejs:26` | Node.js 26 terbaru (lintas base, saat ini Ubuntu 26.04, multi-arch) |
| `nodejs:latest` | target yang terdaftar di `LATEST_TARGETS` (saat ini Node.js 26, multi-arch) |
| `base:ubuntu-26.04` | base Ubuntu 26.04 terbaru (multi-arch) |

Setiap architecture tetap bisa di-pin secara eksplisit kalau dibutuhkan:

```
java:25-ubuntu26.04-amd64
java:25-ubuntu26.04-arm64
nodejs:26-ubuntu26.04-amd64
nodejs:26-ubuntu26.04-arm64
base:ubuntu-26.04-amd64
base:ubuntu-26.04-arm64
```

Tag channel seperti `java:25`, `nodejs:26`, dan `:latest` adalah manifest list
yang berisi kedua architecture tersebut. `os`/`architecture` di dalam manifest otomatis
mengikuti hasil build tiap runner, jadi tidak perlu QEMU atau build lintas-arch.

**2. Build tag (untuk audit/rollback)** — menunjuk satu build tertentu:

```
java:25-ubuntu26.04-<sha git penuh>-<YYYYMMDDHHMMSS>
java:25-ubuntu26.04-<sha git penuh>-<YYYYMMDDHHMMSS>-amd64
java:25-ubuntu26.04-<sha git penuh>-<YYYYMMDDHHMMSS>-arm64
nodejs:26-ubuntu26.04-<sha git penuh>-<YYYYMMDDHHMMSS>
nodejs:26-ubuntu26.04-<sha git penuh>-<YYYYMMDDHHMMSS>-amd64
nodejs:26-ubuntu26.04-<sha git penuh>-<YYYYMMDDHHMMSS>-arm64
base:ubuntu-26.04-<sha git penuh>-<YYYYMMDDHHMMSS>
```

SHA-nya sengaja penuh (40 karakter) supaya tidak ambigu; build stamp membuat
tag tetap unik walau commit yang sama di-rebuild (misalnya base Ubuntu update
atau workflow dijalankan ulang).

Karena tag apa pun tetap bisa ditimpa (GHCR tidak memaksa immutability),
reproduktibilitas penuh hanya didapat dari **digest**. Setelah push, CI
mencetak digest tiap tag di job summary:

```
ghcr.io/agungdh/chiseled-runtimes/java@sha256:...
```

Image juga diberi label OCI `org.opencontainers.image.revision` (SHA penuh)
dan `org.opencontainers.image.created`.

Praktisnya:

- Dev/staging: pakai channel tag (`java:25`) supaya selalu dapat patch.
- Produksi yang butuh reproducibility: pin digest, lalu update lewat
  Renovate/Dependabot dengan format `java:25-ubuntu26.04@sha256:...`.
- Build lama: pakai build tag untuk rollback/audit.

## Build lokal

Butuh Docker (BuildKit). Tanpa argumen, script membangun semua base lalu semua
runtime, menjalankan smoke test, dan (opsional) push. Default-nya hanya
`linux/amd64`; tambahkan `PLATFORMS` untuk arm64.

```bash
./scripts/build-local.sh

# build + push ke registry (tag per-arch, lalu merge jadi multi-arch)
PUSH=true ./scripts/build-local.sh

# amd64 + arm64 (cross-build arm64 di host amd64 butuh QEMU/binfmt)
PLATFORMS="linux/amd64 linux/arm64" ./scripts/build-local.sh

# override registry/owner
REGISTRY=ghcr.io OWNER=agungdh ./scripts/build-local.sh

# override git revision yang dicatat di label/tag
REVISION="$(git rev-parse HEAD)" PUSH=true ./scripts/build-local.sh
```

Dengan `PUSH=true`, tiap architecture di-push sebagai `<tag>-amd64` /
`<tag>-arm64`, lalu `docker buildx imagetools` membuat manifest multi-arch untuk
tag channel (`<tag>`, `<version>`, `:latest`). Jadi `:latest` dan tag lain
otomatis menunjuk ke kedua architecture.

Bisa juga build target tertentu saja. Dependency base akan dibangun otomatis:

```bash
# hanya Java 27 (base 26.10 dibangun sebagai dependency)
./scripts/build-local.sh java/27-ubuntu26.10

# hanya Java 21 (base 26.04 dibangun sebagai dependency)
./scripts/build-local.sh java/21-ubuntu26.04

# hanya Node.js 26 (base 26.04 dibangun sebagai dependency)
./scripts/build-local.sh nodejs/26-ubuntu26.04

# hanya base 26.10
./scripts/build-local.sh base/ubuntu-26.10

# beberapa target sekaligus
./scripts/build-local.sh base/ubuntu-26.04 java/25-ubuntu26.04 nodejs/26-ubuntu26.04
```

Build manual:

```bash
docker build -t ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04 base/ubuntu-26.04

docker build \
  --build-arg BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04 \
  -t ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04 \
  java/25-ubuntu26.04

docker build \
  --build-arg BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04 \
  -t ghcr.io/agungdh/chiseled-runtimes/nodejs:26-ubuntu26.04 \
  nodejs/26-ubuntu26.04
```

## Struktur

```
.
├── .github/workflows/build.yml       # CI: deteksi, build per-arch, merge, push
├── base/
│   ├── ubuntu-26.04/Dockerfile       # chiselled base (chisel -> scratch)
│   └── ubuntu-26.10/Dockerfile
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
│   └── 26-ubuntu26.04/Dockerfile     # Node.js 26 LTS
├── scripts/
│   ├── build-local.sh
│   ├── ci-detect-targets.py          # deteksi target + ekspansi matrix per arch
│   ├── merge-manifests.sh            # gabungkan image per-arch jadi multi-arch
│   ├── push-image.sh                 # push banyak tag + laporkan digest
│   └── smoke/
│       ├── java.sh                   # smoke test per runtime
│       └── nodejs.sh
└── README.md
```

## CI: build selektif dan multi-arch

Workflow tidak memakai QEMU. Job `changes` memindai folder untuk menemukan
target, lalu mengekspansi tiap target menjadi dua build native:

| Architecture | Runner | Platform |
|---|---|---|
| amd64 | `ubuntu-26.04` | `linux/amd64` |
| arm64 | `ubuntu-26.04-arm` | `linux/arm64` |

Setelah kedua build selesai, job `merge_base` / `merge_runtime` memakai
`docker buildx imagetools create` untuk menggabungkan image per-arch menjadi
satu manifest multi-arch. `os`/`architecture` di manifest diisi otomatis dari
image masing-masing, jadi tag channel seperti `:25` dan `:latest` langsung bisa
dipakai di amd64 maupun arm64.

Target yang dibangun tetap selektif:

- Ubah `java/27-ubuntu26.10/**` → hanya Java 27 yang dibangun.
- Ubah `java/25-ubuntu26.04/**` → hanya Java 25 yang dibangun.
- Ubah `java/21-ubuntu26.04/**` → hanya Java 21 yang dibangun.
- Ubah `java/17-ubuntu26.04/**` → hanya Java 17 yang dibangun.
- Ubah `java/11-ubuntu26.04/**` → hanya Java 11 yang dibangun.
- Ubah `java/8-ubuntu26.04/**` → hanya Java 8 yang dibangun.
- Ubah `nodejs/26-ubuntu26.04/**` → hanya Node.js 26 yang dibangun.
- Ubah `nodejs/24-ubuntu26.04/**` → hanya Node.js 24 yang dibangun.
- Ubah `nodejs/22-ubuntu26.04/**` → hanya Node.js 22 yang dibangun.
- Ubah `nodejs/20-ubuntu26.04/**` → hanya Node.js 20 yang dibangun.
- Ubah `nodejs/18-ubuntu26.04/**` → hanya Node.js 18 yang dibangun.
- Ubah `base/ubuntu-26.04/**` → base 26.04 + semua runtime yang memakainya
  (saat ini Java 8, 11, 17, 21, 25 dan Node.js 18, 20, 22, 24, 26), untuk kedua
  architecture.
- Ubah `.github/**` atau `workflow_dispatch` → semua target dibangun.
- Ubah `README.md` / `scripts/**` → tidak ada image yang dibangun.

Runtime baru otomatis terdeteksi selama mengikuti konvensi folder:

```
<runtime>/<versi>-ubuntu<rilis>/Dockerfile
```

Contoh: `php/8.6-ubuntu26.04/Dockerfile`, `python/3.14-ubuntu26.04/Dockerfile`.
Tambahkan juga `scripts/smoke/<runtime>.sh` (menerima image dan platform sebagai
argumen) supaya ikut di-smoke test. Tag `<versi>` (misalnya `:8.6`, `:3.14`)
dibuat otomatis; tag `:latest` hanya untuk target yang terdaftar di
`LATEST_TARGETS` pada workflow.

Kalau base belum ada di registry (PR, build pertama, atau package hilang), CI
membangun base tersebut secara lokal di runner dengan architecture yang sesuai
sebelum membangun runtime-nya. Di push ke `main`, base di-push per-arch lalu
manifest multi-arch-nya dibuat sebelum runtime dibangun.

Setiap image yang di-push juga mendapat build tag per-arch
(`<tag>-<sha penuh>-<YYYYMMDDHHMMSS>-<arch>`), build tag gabungan, channel tag
multi-arch, dan digest-nya dicetak di job summary. Detailnya ada di
[Tag dan versioning](#tag-dan-versioning).

## Update versi

### Java

Versi dan checksum Liberica di-pin di masing-masing `java/*/Dockerfile`
(`LIBERICA_VERSION`, `LIBERICA_SHA256_AMD64`, dan `LIBERICA_SHA256_ARM64`).
Untuk upgrade:

1. Ambil versi terbaru dari API BellSoft:
   `https://api.bell-sw.com/v1/liberica/releases?version-feature=25&os=linux&arch=x86&bitness=64&package-type=tar.gz`
2. Download bundle `jre` untuk kedua architecture:
   `bellsoft-jre<VERSION>-linux-amd64.tar.gz` dan
   `bellsoft-jre<VERSION>-linux-aarch64.tar.gz` (BellSoft memakai `aarch64`
   untuk arm64), lalu hitung `sha256sum` masing-masing.
3. Update `LIBERICA_SHA256_AMD64` dan `LIBERICA_SHA256_ARM64`, build ulang
   (amd64 dan arm64), lalu jalankan smoke test.

Checksum arm64 juga bisa diambil langsung dari field `digest` asset GitHub
release BellSoft.

### Node.js

Versi dan checksum Node.js di-pin di masing-masing `nodejs/*/Dockerfile`
(`NODE_VERSION`, `NODE_SHA256_AMD64`, dan `NODE_SHA256_ARM64`). Hanya versi LTS
(genap) yang disediakan; versi ganjil seperti 19, 21, 23, dan 25 sengaja tidak
dibuat. Node.js 18 dan 20 sudah EOL, tetapi image-nya tetap dibangun selama
folder target masih ada. Untuk upgrade:

1. Ambil versi LTS terbaru dari `https://nodejs.org/dist/index.json`
   (entri dengan field `lts` bukan `false`).
2. Download tarball resmi untuk kedua architecture:
   `node-v<VERSION>-linux-x64.tar.xz` dan
   `node-v<VERSION>-linux-arm64.tar.xz`.
3. Ambil checksum dari
   `https://nodejs.org/dist/v<VERSION>/SHASUMS256.txt`, lalu update
   `NODE_VERSION`, `NODE_SHA256_AMD64`, dan `NODE_SHA256_ARM64`.
4. Build ulang (amd64 dan arm64), lalu jalankan smoke test.

## Catatan ukuran

Base image sekitar 25 MB (uncompressed). Image Java sekitar 390 MB karena bundle
JRE Liberica membawa `lib/modules` dan beberapa CDS archive (`lib/**/*.jsa`).
Kalau nanti butuh jauh lebih kecil, opsinya adalah membuat runtime custom dengan
`jlink` (misalnya `--add-modules ALL-MODULE-PATH --strip-debug --no-man-pages`)
di stage builder.

Image Node.js sekitar 250 MB (uncompressed) karena binary resmi Node.js sendiri
sekitar 145 MB. Header dan dokumentasi sudah dibuang dari tarball; `npm` tetap
disertakan supaya image bisa dipakai untuk menjalankan aplikasi dan tooling.

## Lisensi

- Kode dan konfigurasi di repo ini: lihat lisensi repository.
- Liberica JRE: GPLv2 dengan Classpath Exception. Lihat
  [BellSoft Liberica](https://bell-sw.com/liberica-jdk/) untuk detail.
- Node.js: MIT. `npm` yang dibundel berlisensi Artistic-2.0. Lihat
  [Node.js license](https://github.com/nodejs/node/blob/main/LICENSE) untuk detail.
