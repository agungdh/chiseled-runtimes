#!/usr/bin/env bash
set -euo pipefail

# Push an image under one or more tags and print the resulting digest.
#
# Usage:
#   ./scripts/push-image.sh <image> <repository> <tag> [<tag>...]
#
# Example:
#   ./scripts/push-image.sh \
#     ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04 \
#     ghcr.io/agungdh/chiseled-runtimes/java \
#     25-ubuntu26.04 25 latest
#
# Output (stdout), one line per tag:
#   <tag>\t<repository>@<digest>

if (($# < 3)); then
  printf 'usage: %s <image> <repository> <tag> [<tag>...]\n' "${0##*/}" >&2
  exit 2
fi

image="$1"
repository="${2%/}"
shift 2

push_digest() {
  local ref="$1" output digest

  printf '==> Pushing %s\n' "${ref}" >&2
  output="$(docker push "${ref}" 2>&1)"
  printf '%s\n' "${output}" >&2

  digest="$(printf '%s\n' "${output}" |
    sed -n 's/.*digest: \(sha256:[0-9a-f]\{64\}\).*/\1/p' | tail -n 1)"

  if [[ -z "${digest}" ]]; then
    # Fallback for registries/clients that do not echo the digest.
    digest="$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "${ref}" 2>/dev/null |
      grep -F "${repository}@" | head -n 1 || true)"
    digest="${digest##*@}"
  fi

  if [[ -z "${digest}" ]]; then
    printf 'error: could not determine digest for %s\n' "${ref}" >&2
    return 1
  fi

  printf '%s\n' "${repository}@${digest}"
}

for tag in "$@"; do
  ref="${repository}:${tag}"
  if [[ "${image}" != "${ref}" ]]; then
    docker tag "${image}" "${ref}"
  fi
  digest_ref="$(push_digest "${ref}")"
  printf '%s\t%s\n' "${tag}" "${digest_ref}"
done
