#!/usr/bin/env bash
set -euo pipefail

# Build the chiselled base image and the Liberica Java images locally.
#
# Usage:
#   ./scripts/build-local.sh              # build (and smoke test) only
#   PUSH=true ./scripts/build-local.sh    # build, smoke test, then push
#
# Environment overrides:
#   REGISTRY  container registry to tag images for (default: ghcr.io)
#   OWNER     repository owner / namespace        (default: agungdh)
#   REPO      repository name                     (default: chiseled-runtimes)
#   PLATFORM  target platform                     (default: linux/amd64)
#   PUSH      push images after a successful build (default: false)

REGISTRY="${REGISTRY:-ghcr.io}"
OWNER="${OWNER:-agungdh}"
REPO="${REPO:-chiseled-runtimes}"
PLATFORM="${PLATFORM:-linux/amd64}"
PUSH="${PUSH:-false}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PAIRS=(
  "26.04:25"
  "26.10:27"
)

for pair in "${PAIRS[@]}"; do
  ubuntu="${pair%%:*}"
  java="${pair##*:}"

  base_image="${REGISTRY}/${OWNER}/${REPO}/base:ubuntu-${ubuntu}"
  java_image="${REGISTRY}/${OWNER}/${REPO}/java:${java}-ubuntu${ubuntu}"

  printf 'Building %s\n' "${base_image}"
  docker build \
    --platform "${PLATFORM}" \
    --tag "${base_image}" \
    "${ROOT_DIR}/base/ubuntu-${ubuntu}"

  printf 'Building %s\n' "${java_image}"
  docker build \
    --platform "${PLATFORM}" \
    --build-arg "BASE_IMAGE=${base_image}" \
    --tag "${java_image}" \
    "${ROOT_DIR}/java/${java}-ubuntu${ubuntu}"

  printf 'Smoke testing %s\n' "${java_image}"
  docker run --rm --platform "${PLATFORM}" "${java_image}" java -version

  if [[ "${PUSH}" == "true" ]]; then
    printf 'Pushing %s\n' "${base_image}"
    docker push "${base_image}"

    printf 'Pushing %s\n' "${java_image}"
    docker push "${java_image}"
  fi
done
