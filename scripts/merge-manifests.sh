#!/usr/bin/env bash
set -euo pipefail

# Combine per-architecture images into a single multi-arch manifest and tag it.
#
# Usage:
#   ./scripts/merge-manifests.sh <repository> <tag>[,<tag>...] <source> [<source>...]
#
# Example:
#   ./scripts/merge-manifests.sh \
#     ghcr.io/agungdh/chiseled-runtimes/java \
#     "25-ubuntu26.04,25,latest" \
#     ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04-amd64 \
#     ghcr.io/agungdh/chiseled-runtimes/java:25-ubuntu26.04-arm64
#
# Output (stdout), one line per destination tag:
#   <tag>\t<repository>@<digest>

if (($# < 3)); then
  printf 'usage: %s <repository> <tag>[,<tag>...] <source> [<source>...]\n' "${0##*/}" >&2
  exit 2
fi

repository="${1%/}"
tags_csv="$2"
shift 2

IFS=',' read -r -a tags <<< "${tags_csv}"
if ((${#tags[@]} == 0)); then
  printf 'error: no destination tags given\n' >&2
  exit 2
fi

printf '==> Creating multi-arch manifest %s from %d source image(s)\n' \
  "${repository}:${tags[0]}" "$#" >&2

args=()
for tag in "${tags[@]}"; do
  [[ -n "${tag}" ]] || continue
  args+=(-t "${repository}:${tag}")
done

docker buildx imagetools create "${args[@]}" "$@"

for tag in "${tags[@]}"; do
  [[ -n "${tag}" ]] || continue
  ref="${repository}:${tag}"
  digest="$(docker buildx imagetools inspect "${ref}" |
    sed -n 's/^Digest:[[:space:]]*//p' | head -n 1)"

  if [[ -z "${digest}" ]]; then
    printf 'error: could not determine digest for %s\n' "${ref}" >&2
    exit 1
  fi

  printf '%s\t%s@%s\n' "${tag}" "${repository}" "${digest}"
done
