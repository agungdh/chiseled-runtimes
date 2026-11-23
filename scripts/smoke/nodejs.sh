#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: nodejs.sh <image> [platform]}"
platform="${2:-linux/amd64}"

docker run --rm --platform "$platform" "$image" node --version
docker run --rm --platform "$platform" "$image" npm --version
docker run --rm --platform "$platform" "$image" node -e 'console.log(process.version, process.arch, process.platform)'
