#!/usr/bin/env bash
set -euo pipefail

# Build chiselled common bases, language bases and runtime images locally.
#
# Usage:
#   ./scripts/build-local.sh                                  # build everything
#   ./scripts/build-local.sh java/27-ubuntu26.10              # one runtime only
#   ./scripts/build-local.sh base/ubuntu-26.10                # one common base only
#   ./scripts/build-local.sh base/java-ubuntu-26.04           # one language base only
#   ./scripts/build-local.sh base/java-ubuntu-26.04 java/25-ubuntu26.04
#   PUSH=true ./scripts/build-local.sh java/25-ubuntu26.04
#
# Environment overrides:
#   REGISTRY        container registry to tag images for (default: ghcr.io)
#   OWNER           repository owner / namespace        (default: agungdh)
#   REPO            repository name                     (default: chiseled-runtimes)
#   PLATFORMS       target platforms, space separated   (default: linux/amd64)
#                   use "linux/amd64 linux/arm64" for both; cross-building
#                   arm64 on an amd64 host needs QEMU/binfmt locally
#   PLATFORM        legacy single-platform override (used when PLATFORMS is unset)
#   PUSH            push images after a successful build (default: false)
#   LATEST_TARGETS  space-separated targets that also get :latest
#                   (default: java/25-ubuntu26.04 nodejs/26-ubuntu26.04
#                   bun/1-ubuntu26.04 dotnet/11.0-ubuntu26.10
#                   aspnet/11.0-ubuntu26.10)
#   REVISION        git revision recorded in labels/tags (default: current HEAD)
#
# With PUSH=true each architecture is pushed under <tag>-<arch> and then merged
# into the regular channel tags (<tag>, <version>, :latest) as a multi-arch
# manifest. The merge uses `docker buildx imagetools`, so Buildx is required.

REGISTRY="${REGISTRY:-ghcr.io}"
OWNER="${OWNER:-agungdh}"
REPO="${REPO:-chiseled-runtimes}"
PLATFORMS="${PLATFORMS:-${PLATFORM:-linux/amd64}}"
PUSH="${PUSH:-false}"
LATEST_TARGETS="${LATEST_TARGETS:-java/25-ubuntu26.04 nodejs/26-ubuntu26.04 bun/1-ubuntu26.04 dotnet/11.0-ubuntu26.10 aspnet/11.0-ubuntu26.10}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

REVISION="${REVISION:-$(git rev-parse HEAD 2>/dev/null || true)}"
REVISION="${REVISION:-unknown}"
CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BUILD_STAMP="$(date -u +%Y%m%d%H%M%S)"

read -r -a platforms <<< "${PLATFORMS}"
arches=()
for platform in "${platforms[@]}"; do
  case "${platform}" in
    linux/amd64) arch="amd64" ;;
    linux/arm64 | linux/arm64/v8) arch="arm64" ;;
    *)
      printf 'error: unsupported platform %s (use linux/amd64 or linux/arm64)\n' "${platform}" >&2
      exit 1
      ;;
  esac
  [[ " ${arches[*]} " == *" ${arch} "* ]] || arches+=("${arch}")
done

BUILT_COMMON=()
BUILT_LANG=()
COMMON_MERGES=()
LANG_MERGES=()
RUNTIME_MERGES=()

add_unique() {
  local array_name="$1" value="$2" existing
  local -n array="${array_name}"
  for existing in "${array[@]}"; do
    [[ "${existing}" == "${value}" ]] && return 0
  done
  array+=("${value}")
}

common_is_built() {
  local release="$1" arch="$2" built
  for built in "${BUILT_COMMON[@]}"; do
    [[ "${built}" == "${release}:${arch}" ]] && return 0
  done
  return 1
}

lang_is_built() {
  local runtime="$1" release="$2" arch="$3" built
  for built in "${BUILT_LANG[@]}"; do
    [[ "${built}" == "${runtime}:${release}:${arch}" ]] && return 0
  done
  return 1
}

image_repo() {
  printf '%s/%s/%s/%s' "${REGISTRY}" "${OWNER}" "${REPO}" "$1"
}

image_ref() {
  printf '%s:%s' "$(image_repo "$1")" "$2"
}

# push_images <image> <repository> <tag>...
push_images() {
  local image="$1" repository="$2" tag digest_ref lines
  shift 2

  lines="$(scripts/push-image.sh "${image}" "${repository}" "$@")"
  while IFS=$'\t' read -r tag digest_ref; do
    [[ -n "${tag}" ]] || continue
    printf '==> Pushed %s\n    %s\n' "${repository}:${tag}" "${digest_ref}"
  done <<< "${lines}"
}

# merge_tags <repository> <comma-separated tags> <arch>...
merge_tags() {
  local repository="$1" tags="$2" tag digest_ref lines
  shift 2

  lines="$(scripts/merge-manifests.sh "${repository}" "${tags}" "$@")"
  while IFS=$'\t' read -r tag digest_ref; do
    [[ -n "${tag}" ]] || continue
    printf '==> Merged %s\n    %s\n' "${repository}:${tag}" "${digest_ref}"
  done <<< "${lines}"
}

build_common_arch() {
  local release="$1" arch="$2"
  local dir="base/ubuntu-${release}"
  local ref unique_tag

  ref="$(image_ref base "ubuntu-${release}-${arch}")"
  printf '==> Building %s (%s, linux/%s)\n' "${ref}" "${dir}" "${arch}"
  docker build \
    --platform "linux/${arch}" \
    --build-arg "TARGETARCH=${arch}" \
    --label "org.opencontainers.image.revision=${REVISION}" \
    --label "org.opencontainers.image.created=${CREATED}" \
    --tag "${ref}" \
    "${dir}"
  BUILT_COMMON+=("${release}:${arch}")

  if [[ "${PUSH}" == "true" ]]; then
    unique_tag="ubuntu-${release}-${REVISION}-${BUILD_STAMP}-${arch}"
    push_images "${ref}" "$(image_repo base)" "ubuntu-${release}-${arch}" "${unique_tag}"
    add_unique COMMON_MERGES "${release}"
  fi
}

build_common() {
  local release="$1" arch
  for arch in "${arches[@]}"; do
    build_common_arch "${release}" "${arch}"
  done
}

ensure_common() {
  local release="$1" arch="$2"
  common_is_built "${release}" "${arch}" && return 0
  build_common_arch "${release}" "${arch}"
}

build_lang_arch() {
  local runtime="$1" release="$2" arch="$3"
  local dir="base/${runtime}-ubuntu-${release}"
  local common_ref ref unique_tag

  ensure_common "${release}" "${arch}"

  common_ref="$(image_ref base "ubuntu-${release}-${arch}")"
  ref="$(image_ref base "${runtime}-ubuntu-${release}-${arch}")"
  printf '==> Building %s (%s, linux/%s)\n' "${ref}" "${dir}" "${arch}"
  docker build \
    --platform "linux/${arch}" \
    --build-arg "TARGETARCH=${arch}" \
    --build-arg "COMMON_BASE_IMAGE=${common_ref}" \
    --label "org.opencontainers.image.revision=${REVISION}" \
    --label "org.opencontainers.image.created=${CREATED}" \
    --tag "${ref}" \
    "${dir}"
  BUILT_LANG+=("${runtime}:${release}:${arch}")

  if [[ "${PUSH}" == "true" ]]; then
    unique_tag="${runtime}-ubuntu-${release}-${REVISION}-${BUILD_STAMP}-${arch}"
    push_images "${ref}" "$(image_repo base)" "${runtime}-ubuntu-${release}-${arch}" "${unique_tag}"
    add_unique LANG_MERGES "${runtime}:${release}"
  fi
}

build_lang() {
  local runtime="$1" release="$2" arch
  for arch in "${arches[@]}"; do
    build_lang_arch "${runtime}" "${release}" "${arch}"
  done
}

ensure_lang() {
  local runtime="$1" release="$2" arch="$3"
  lang_is_built "${runtime}" "${release}" "${arch}" && return 0
  build_lang_arch "${runtime}" "${release}" "${arch}"
}

build_runtime() {
  local dir="$1"
  local runtime base_runtime tag version ubuntu base_dir ref smoke
  local arch base_ref unique_tag latest=false
  local -a push_tags

  runtime="$(basename "$(dirname "${dir}")")"
  tag="$(basename "${dir}")"
  version="${tag%%-ubuntu*}"
  ubuntu="${tag##*-ubuntu}"

  # ASP.NET Core is part of the .NET platform and needs the same native
  # dependencies, so its images reuse the .NET language base.
  base_runtime="${runtime}"
  case "${runtime}" in
    aspnet) base_runtime="dotnet" ;;
  esac
  base_dir="base/${base_runtime}-ubuntu-${ubuntu}"

  if [[ ! -f "${base_dir}/Dockerfile" ]]; then
    printf 'error: %s depends on missing %s\n' "${dir}" "${base_dir}" >&2
    return 1
  fi

  [[ " ${LATEST_TARGETS} " == *" ${dir} "* ]] && latest=true

  for arch in "${arches[@]}"; do
    ensure_lang "${base_runtime}" "${ubuntu}" "${arch}"
    base_ref="$(image_ref base "${base_runtime}-ubuntu-${ubuntu}-${arch}")"

    ref="$(image_ref "${runtime}" "${tag}-${arch}")"
    printf '==> Building %s (%s, linux/%s)\n' "${ref}" "${dir}" "${arch}"
    docker build \
      --platform "linux/${arch}" \
      --build-arg "TARGETARCH=${arch}" \
      --build-arg "BASE_IMAGE=${base_ref}" \
      --label "org.opencontainers.image.revision=${REVISION}" \
      --label "org.opencontainers.image.created=${CREATED}" \
      --tag "${ref}" \
      "${dir}"

    smoke="scripts/smoke/${runtime}.sh"
    if [[ -x "${smoke}" ]]; then
      printf '==> Smoke testing %s\n' "${ref}"
      "${smoke}" "${ref}" "linux/${arch}"
    else
      printf 'warning: no smoke test for %s (%s)\n' "${runtime}" "${smoke}" >&2
    fi

    if [[ "${PUSH}" == "true" ]]; then
      unique_tag="${tag}-${REVISION}-${BUILD_STAMP}-${arch}"
      push_tags=("${tag}-${arch}" "${unique_tag}" "${version}-${arch}")
      if [[ "${latest}" == "true" ]]; then
        push_tags+=("latest-${arch}")
      fi
      push_images "${ref}" "$(image_repo "${runtime}")" "${push_tags[@]}"
      add_unique RUNTIME_MERGES "${dir}"
    fi
  done
}

merge_common_bases() {
  local release repository tags arch
  local -a sources

  for release in "${COMMON_MERGES[@]}"; do
    repository="$(image_repo base)"
    tags="ubuntu-${release},ubuntu-${release}-${REVISION}-${BUILD_STAMP}"
    sources=()
    for arch in "${arches[@]}"; do
      sources+=("${repository}:ubuntu-${release}-${arch}")
    done
    merge_tags "${repository}" "${tags}" "${sources[@]}"
  done
}

merge_lang_bases() {
  local key runtime release repository tag tags arch
  local -a sources

  for key in "${LANG_MERGES[@]}"; do
    runtime="${key%%:*}"
    release="${key##*:}"
    repository="$(image_repo base)"
    tag="${runtime}-ubuntu-${release}"
    tags="${tag},${tag}-${REVISION}-${BUILD_STAMP}"
    sources=()
    for arch in "${arches[@]}"; do
      sources+=("${repository}:${tag}-${arch}")
    done
    merge_tags "${repository}" "${tags}" "${sources[@]}"
  done
}

merge_runtimes() {
  local dir runtime tag version ubuntu repository tags arch latest
  local -a sources

  for dir in "${RUNTIME_MERGES[@]}"; do
    runtime="$(basename "$(dirname "${dir}")")"
    tag="$(basename "${dir}")"
    version="${tag%%-ubuntu*}"
    ubuntu="${tag##*-ubuntu}"
    repository="$(image_repo "${runtime}")"

    tags="${tag},${tag}-${REVISION}-${BUILD_STAMP}"
    [[ "${version}" != "${tag}" ]] && tags+=",${version}"
    if [[ " ${LATEST_TARGETS} " == *" ${dir} "* ]]; then
      tags+=",latest"
    fi

    sources=()
    for arch in "${arches[@]}"; do
      sources+=("${repository}:${tag}-${arch}")
    done
    merge_tags "${repository}" "${tags}" "${sources[@]}"
  done
}

discover_targets() {
  local dir

  # Common bases: base/ubuntu-<release>
  while IFS= read -r dir; do
    printf '%s\n' "${dir}"
  done < <(find base -mindepth 1 -maxdepth 1 -type d -name 'ubuntu-*' | sort)

  # Language bases: base/<runtime>-ubuntu-<release>
  while IFS= read -r dir; do
    printf '%s\n' "${dir}"
  done < <(find base -mindepth 1 -maxdepth 1 -type d -name '*-ubuntu-*' \
    ! -name 'ubuntu-*' | sort)

  # Runtime images: <runtime>/<version>-ubuntu<release>
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
      build_common "${target#base/ubuntu-}"
      ;;
    base/*-ubuntu-*)
      rest="${target#base/}"
      build_lang "${rest%%-ubuntu-*}" "${rest##*-ubuntu-}"
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

if [[ "${PUSH}" == "true" ]]; then
  merge_common_bases
  merge_lang_bases
  merge_runtimes
fi
