# chiseled-runtimes

Image container "chiselled" (minimal, tanpa shell) untuk berbagai runtime, dibangun
di atas [Ubuntu](https://ubuntu.com/) + [chisel](https://github.com/canonical/chisel)
dari Canonical.

Saat ini fokus di **Java** dengan distribusi **[BellSoft Liberica](https://bell-sw.com/liberica-jdk/)**.
Runtime lain (`nodejs`, `php`, dst.) menyusul dengan pola yang sama.

## Image yang tersedia

| Image | Java | Base | Keterangan |
|---|---|---|---|
| `ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04` | Liberica JRE 25 | Ubuntu 26.04 | LTS, juga tersedia sebagai `:25` dan `:latest` |
| `ghcr.io/agungdh/chiseled-runtimes/java:27-ubuntu26.10` | Liberica JRE 27 | Ubuntu 26.10 | juga tersedia sebagai `:27` |
| `ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04` | - | Ubuntu 26.04 | base image tanpa Java |
| `ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.10` | - | Ubuntu 26.10 | base image tanpa Java |

Karakteristik image Java:

- Hanya berisi **JRE** (bukan JDK), tanpa JavaFX.
- Berjalan sebagai user non-root `app` (uid/gid `10001`), `WORKDIR /app`.
- `JAVA_HOME=/opt/java/openjdk`, `PATH` sudah menunjuk ke `java`.
- Tanpa shell, tanpa package manager (distroless-style).
- Sudah termasuk CA certificates, timezone data (`TZ=UTC`), dan font
  (DejaVu + fontconfig) untuk kebutuhan AWT/PDF.
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

## Build lokal

Butuh Docker (BuildKit). Tanpa argumen, script membangun semua base lalu semua
runtime, menjalankan smoke test, dan (opsional) push:

```bash
./scripts/build-local.sh

# build + push ke registry
PUSH=true ./scripts/build-local.sh

# override registry/owner/platform
REGISTRY=ghcr.io OWNER=agungdh PLATFORM=linux/amd64 ./scripts/build-local.sh
```

Bisa juga build target tertentu saja. Dependency base akan dibangun otomatis:

```bash
# hanya Java 27 (base 26.10 dibangun sebagai dependency)
./scripts/build-local.sh java/27-ubuntu26.10

# hanya base 26.10
./scripts/build-local.sh base/ubuntu-26.10

# beberapa target sekaligus
./scripts/build-local.sh base/ubuntu-26.04 java/25-ubuntu26.04
```

Build manual:

```bash
docker build -t ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04 base/ubuntu-26.04

docker build \
  --build-arg BASE_IMAGE=ghcr.io/agungdh/chiseled-runtimes/base:ubuntu-26.04 \
  -t ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04 \
  java/25-ubuntu26.04
```

## Struktur

```
.
├── .github/workflows/build.yml       # CI: deteksi perubahan, build, smoke test, push
├── base/
│   ├── ubuntu-26.04/Dockerfile       # chiselled base (chisel -> scratch)
│   └── ubuntu-26.10/Dockerfile
├── java/
│   ├── 25-ubuntu26.04/Dockerfile     # Liberica JRE 25
│   └── 27-ubuntu26.10/Dockerfile     # Liberica JRE 27
├── scripts/
│   ├── build-local.sh
│   ├── ci-detect-targets.py          # deteksi target yang berubah di CI
│   └── smoke/
│       └── java.sh                   # smoke test per runtime
└── README.md
```

## CI: build selektif

Workflow tidak memakai matrix statis. Job `changes` memindai folder untuk
menemukan target, lalu hanya membangun yang terpengaruh:

- Ubah `java/27-ubuntu26.10/**` → hanya Java 27 yang dibangun.
- Ubah `java/25-ubuntu26.04/**` → hanya Java 25 yang dibangun.
- Ubah `base/ubuntu-26.04/**` → base 26.04 + semua runtime yang memakainya
  (saat ini Java 25).
- Ubah `.github/**` atau `workflow_dispatch` → semua target dibangun.
- Ubah `README.md` / `scripts/**` → tidak ada image yang dibangun.

Runtime baru otomatis terdeteksi selama mengikuti konvensi folder:

```
<runtime>/<versi>-ubuntu<rilis>/Dockerfile
```

Contoh: `nodejs/24-ubuntu26.04/Dockerfile`, `php/8.6-ubuntu26.04/Dockerfile`.
Tambahkan juga `scripts/smoke/<runtime>.sh` (menerima image dan platform sebagai
argumen) supaya ikut di-smoke test. Tag `<versi>` (misalnya `:24`, `:8.6`) dibuat
otomatis; tag `:latest` hanya untuk target yang terdaftar di `LATEST_TARGETS`
pada workflow.

Kalau base belum ada di registry (PR, build pertama, atau package hilang), CI
membangun base tersebut secara lokal sebelum membangun runtime-nya.

## Update versi

Versi dan checksum Liberica di-pin di masing-masing `java/*/Dockerfile`
(`LIBERICA_VERSION` dan `LIBERICA_SHA256`). Untuk upgrade:

1. Ambil versi terbaru dari API BellSoft:
   `https://api.bell-sw.com/v1/liberica/releases?version-feature=25&os=linux&arch=x86&bitness=64&package-type=tar.gz`
2. Download bundle `jre` (`bellsoft-jre<VERSION>-linux-amd64.tar.gz`), lalu hitung
   `sha256sum`.
3. Update kedua `ARG` tersebut, build ulang, dan jalankan smoke test.

## Catatan ukuran

Base image sekitar 25 MB (uncompressed). Image Java sekitar 390 MB karena bundle
JRE Liberica membawa `lib/modules` dan beberapa CDS archive (`lib/**/*.jsa`).
Kalau nanti butuh jauh lebih kecil, opsinya adalah membuat runtime custom dengan
`jlink` (misalnya `--add-modules ALL-MODULE-PATH --strip-debug --no-man-pages`)
di stage builder.

## Lisensi

- Kode dan konfigurasi di repo ini: lihat lisensi repository.
- Liberica JRE: GPLv2 dengan Classpath Exception. Lihat
  [BellSoft Liberica](https://bell-sw.com/liberica-jdk/) untuk detail.
