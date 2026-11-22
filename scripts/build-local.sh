#!/usr/bin/env bash
set -euo pipefail

# Build chiselled base images and runtime images locally.
#
# Usage:
#   ./scripts/build-local.sh                                 # build everything
#   ./scripts/build-local.sh java/27-ubuntu26.10             # one runtime only
#   ./scripts/build-local.sh base/ubuntu-26.10               # one base only
#   ./scripts/build-local.sh base/ubuntu-26.10 java/27-ubuntu26.10
#   PUSH=true ./scripts/build-local.sh java/25-ubuntu26.04
#
# Environment overrides:
#   REGISTRY        container registry to tag images for (default: ghcr.io)
#   OWNER           repository owner / namespace        (default: agungdh)
#   REPO            repository name                     (default: chiseled-runtimes)
#   PLATFORM        target platform                     (default: linux/amd64)
#   PUSH            push images after a successful build (default: false)
#   LATEST_TARGETS  space-separated targets that also get :latest
#                   (default: java/25-ubuntu26.04)

REGISTRY="${REGISTRY:-ghcr.io}"
OWNER="${OWNER:-agungdh}"
REPO="${REPO:-chiseled-runtimes}"
PLATFORM="${PLATFORM:-linux/amd64}"
PUSH="${PUSH:-false}"
LATEST_TARGETS="${LATEST_TARGETS:-java/25-ubuntu26.04}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

BUILT_BASES=" "

mark_base_built() {
  BUILT_BASES+="$1 "
}

base_is_built() {
  [[ "${BUILT_BASES}" == *" $1 "* ]]
}

image_ref() {
  printf '%s/%s/%s/%s:%s' "${REGISTRY}" "${OWNER}" "${REPO}" "$1" "$2"
}

build_base() {
  local ubuntu="$1"
  local dir="base/ubuntu-${ubuntu}"
  local ref
  ref="$(image_ref base "ubuntu-${ubuntu}")"

  printf '==> Building %s (%s)\n' "${ref}" "${dir}"
  docker build --platform "${PLATFORM}" --tag "${ref}" "${dir}"
  mark_base_built "${ubuntu}"

  if [[ "${PUSH}" == "true" ]]; then
    printf '==> Pushing %s\n' "${ref}"
    docker push "${ref}"
  fi
}

build_runtime() {
  local dir="$1"
  local runtime tag version ubuntu base_dir base_ref ref smoke version_ref latest_ref

  runtime="$(basename "$(dirname "${dir}")")"
  tag="$(basename "${dir}")"
  version="${tag%%-ubuntu*}"
  ubuntu="${tag##*-ubuntu}"
  base_dir="base/ubuntu-${ubuntu}"

  if [[ ! -f "${base_dir}/Dockerfile" ]]; then
    printf 'error: %s depends on missing %s\n' "${dir}" "${base_dir}" >&2
    return 1
  fi

  base_ref="$(image_ref base "ubuntu-${ubuntu}")"
  if ! base_is_built "${ubuntu}"; then
    printf '==> Building dependency %s (%s)\n' "${base_ref}" "${base_dir}"
    docker build --platform "${PLATFORM}" --tag "${base_ref}" "${base_dir}"
    mark_base_built "${ubuntu}"
  fi

  ref="$(image_ref "${runtime}" "${tag}")"
  printf '==> Building %s (%s)\n' "${ref}" "${dir}"
  docker build \
    --platform "${PLATFORM}" \
    --build-arg "BASE_IMAGE=${base_ref}" \
    --tag "${ref}" \
    "${dir}"

  smoke="scripts/smoke/${runtime}.sh"
  if [[ -x "${smoke}" ]]; then
    printf '==> Smoke testing %s\n' "${ref}"
    "${smoke}" "${ref}" "${PLATFORM}"
  else
    printf 'warning: no smoke test for %s (%s)\n' "${runtime}" "${smoke}" >&2
  fi

  if [[ "${PUSH}" == "true" ]]; then
    printf '==> Pushing %s\n' "${ref}"
    docker push "${ref}"

    version_ref="$(image_ref "${runtime}" "${version}")"
    printf '==> Pushing %s\n' "${version_ref}"
    docker tag "${ref}" "${version_ref}"
    docker push "${version_ref}"

    if [[ " ${LATEST_TARGETS} " == *" ${dir} "* ]]; then
      latest_ref="$(image_ref "${runtime}" latest)"
      printf '==> Pushing %s\n' "${latest_ref}"
      docker tag "${ref}" "${latest_ref}"
      docker push "${latest_ref}"
    fi
  fi
}

discover_targets() {
  local dir
  while IFS= read -r dir; do
    printf '%s\n' "${dir}"
  done < <(find base -mindepth 1 -maxdepth 1 -type d -name 'ubuntu-*' | sort)

  while IFS= read -r dir; do
    [[ -f "${dir}/Dockerfile" ]] || continue
    printf '%s\n' "${dir#./}"
  done < <(find . -mindepth 2 -maxdepth 2 -type d -name '*-ubuntu*' \
    -not -path './.git/*' \
    -not -path './base/*' \
    -not -path './scripts/*' \
    -not -path './.github/*' | sort)
}

targets=()
if (($# > 0)); then
  targets=("$@")
else
  while IFS= read -r target; do
    targets+=("${target}")
  done < <(discover_targets)
fi

if ((${#targets[@]} == 0)); then
  printf 'No targets found.\n'
  exit 0
fi

for target in "${targets[@]}"; do
  target="${target%/}"

  if [[ ! -f "${target}/Dockerfile" ]]; then
    printf 'error: %s is not a target directory (no Dockerfile)\n' "${target}" >&2
    exit 1
  fi

  case "${target}" in
    base/ubuntu-*)
      build_base "${target#base/ubuntu-}"
      ;;
    *-ubuntu*)
      build_runtime "${target}"
      ;;
    *)
      printf 'error: cannot determine target type for %s\n' "${target}" >&2
      exit 1
      ;;
  esac
done
