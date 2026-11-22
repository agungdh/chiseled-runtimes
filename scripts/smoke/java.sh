#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: java.sh <image> [platform]}"
platform="${2:-linux/amd64}"

docker run --rm --platform "$platform" "$image" java -version
