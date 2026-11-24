#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: bun.sh <image> [platform]}"
platform="${2:-linux/amd64}"

docker run --rm --platform "$platform" "$image" bun --version
docker run --rm --platform "$platform" "$image" bun -e 'console.log(Bun.version, process.arch, process.platform)'
