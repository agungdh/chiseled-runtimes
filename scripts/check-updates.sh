#!/usr/bin/env bash
set -euo pipefail

# Check the pinned runtime versions in every Dockerfile against upstream.
# By default this script only reports; with --apply it also rewrites the
# version and checksum ARGs in place.
#
# Usage:
#   ./scripts/check-updates.sh
#   ./scripts/check-updates.sh --apply
#   ./scripts/check-updates.sh --help
#
# Exit status:
#   0  all pinned versions are up to date (or the updates were applied)
#   1  updates are available (check mode only)
#   2  usage error
#
# Sources:
#   chisel   -> latest stable release on GitHub (canonical/chisel)
#   Bun      -> latest stable Bun <major> release on GitHub (oven-sh/bun)
#   Node.js  -> latest release of the same major from nodejs.org/dist/index.json
#   Java     -> latest Liberica release for the same feature version that ships
#               a plain JRE tarball (bell-sw/Liberica); CRaC-only builds skipped
#   .NET     -> latest runtime of the same channel (major.minor) from
#               builds.dotnet.microsoft.com/dotnet/release-metadata
#   ASP.NET  -> the ASP.NET Core runtime from the same .NET channel
#
# Set GITHUB_TOKEN (or GH_TOKEN) to raise the GitHub API rate limit.

usage() {
  cat <<'EOF'
Check the pinned runtime versions in every Dockerfile against upstream.

By default this script only reports; with --apply it also rewrites the
version and checksum ARGs in place.

Usage:
  ./scripts/check-updates.sh
  ./scripts/check-updates.sh --apply
  ./scripts/check-updates.sh --help

Exit status:
  0  all pinned versions are up to date (or the updates were applied)
  1  updates are available (check mode only)
  2  usage error

Sources:
  chisel   -> latest stable release on GitHub (canonical/chisel)
  Bun      -> latest stable Bun <major> release on GitHub (oven-sh/bun)
  Node.js  -> latest release of the same major from nodejs.org/dist/index.json
  Java     -> latest Liberica release for the same feature version that ships
              a plain JRE tarball (bell-sw/Liberica); CRaC-only builds skipped
  .NET     -> latest runtime of the same channel (major.minor) from
              builds.dotnet.microsoft.com/dotnet/release-metadata
  ASP.NET  -> the ASP.NET Core runtime from the same .NET channel

Set GITHUB_TOKEN (or GH_TOKEN) to raise the GitHub API rate limit.
EOF
}

APPLY=false

case "${1:-}" in
  "") ;;
  --apply)
    APPLY=true
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf 'error: unknown argument %s (supported: --apply)\n' "${1}" >&2
    usage >&2
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

command -v curl >/dev/null 2>&1 || { printf 'error: curl is required\n' >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf 'error: python3 is required\n' >&2; exit 1; }

AUTH=()
if [[ -n "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ]]; then
  AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN:-${GH_TOKEN:-}}")
fi

gh_api() {
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: chiseled-runtimes-check-updates" \
    "${AUTH[@]}" \
    "https://api.github.com$1"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

printf '==> Fetching upstream metadata\n'
CHISEL_LATEST="$(gh_api /repos/canonical/chisel/releases/latest |
  python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])')"
gh_api "/repos/oven-sh/bun/releases?per_page=30" >"${TMP_DIR}/bun.json"
gh_api "/repos/bell-sw/Liberica/releases?per_page=100&page=1" >"${TMP_DIR}/liberica-1.json"
gh_api "/repos/bell-sw/Liberica/releases?per_page=100&page=2" >"${TMP_DIR}/liberica-2.json"
python3 - "${TMP_DIR}/liberica-1.json" "${TMP_DIR}/liberica-2.json" >"${TMP_DIR}/liberica.json" <<'PY'
import json
import sys

releases = []
for path in sys.argv[1:]:
    try:
        releases.extend(json.load(open(path)))
    except (OSError, ValueError):
        pass
json.dump(releases, sys.stdout)
PY
curl -fsSL "https://nodejs.org/dist/index.json" >"${TMP_DIR}/node-index.json"

node_latest() { # <major>
  python3 - "${TMP_DIR}/node-index.json" "$1" <<'PY'
import json
import sys

index = json.load(open(sys.argv[1]))
major = int(sys.argv[2])
for entry in index:
    version = entry["version"]
    if version.startswith(f"v{major}."):
        print(version[1:])
        break
PY
}

bun_latest() { # <major>
  python3 - "${TMP_DIR}/bun.json" "$1" <<'PY'
import json
import re
import sys

releases = json.load(open(sys.argv[1]))
major = sys.argv[2]
required = {"bun-linux-x64.zip", "bun-linux-aarch64.zip"}
for release in releases:
    if release.get("prerelease"):
        continue
    tag = release["tag_name"]
    match = re.match(r"bun-v(\d+)\.", tag)
    if not match or match.group(1) != major:
        continue
    if required <= {asset["name"] for asset in release.get("assets", [])}:
        print(tag)
        break
PY
}

liberica_latest() { # <feature version>
  python3 - "${TMP_DIR}/liberica.json" "$1" <<'PY'
import json
import re
import sys

releases = json.load(open(sys.argv[1]))
feature = sys.argv[2]
pattern = re.compile(rf"^{re.escape(feature)}(?:u|\.)")
for release in releases:
    if release.get("prerelease"):
        continue
    tag = release["tag_name"]
    if not pattern.match(tag):
        continue
    names = {asset["name"] for asset in release.get("assets", [])}
    # Skip CRaC-only builds (e.g. 17.0.21.1+6): they carry no plain JRE tarball.
    if (
        f"bellsoft-jre{tag}-linux-amd64.tar.gz" in names
        and f"bellsoft-jre{tag}-linux-aarch64.tar.gz" in names
    ):
        print(tag)
        break
PY
}

DOTNET_METADATA_DIR="${TMP_DIR}/dotnet"
mkdir -p "${DOTNET_METADATA_DIR}"

dotnet_releases() { # <channel> -> path to the cached releases.json
  local channel="$1"
  local file="${DOTNET_METADATA_DIR}/releases-${channel}.json"

  if [[ ! -f "${file}" ]]; then
    curl -fsSL \
      "https://builds.dotnet.microsoft.com/dotnet/release-metadata/${channel}/releases.json" \
      >"${file}"
  fi

  printf '%s\n' "${file}"
}

dotnet_latest() { # <channel>
  python3 - "$(dotnet_releases "$1")" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
print(data.get("latest-runtime") or data["releases"][0]["release-version"])
PY
}

dotnet_checksums() { # <channel> <version> <runtime|aspnetcore-runtime> -> "<amd64> <arm64>"
  python3 - "$(dotnet_releases "$1")" "$2" "$3" <<'PY'
import json
import sys

path, version, section = sys.argv[1:4]
prefix = "dotnet-runtime-" if section == "runtime" else "aspnetcore-runtime-"
data = json.load(open(path))
for release in data["releases"]:
    if release["release-version"] != version:
        continue
    found = {}
    for entry in release[section]["files"]:
        name = entry["name"]
        if not name.startswith(prefix) or "-composite" in name:
            continue
        if name.endswith("-linux-x64.tar.gz"):
            found["amd64"] = entry["hash"]
        elif name.endswith("-linux-arm64.tar.gz"):
            found["arm64"] = entry["hash"]
    print(found.get("amd64", ""), found.get("arm64", ""))
    break
PY
}

node_checksums() { # <version> -> "<amd64> <arm64>"
  local version="$1"
  local file="${TMP_DIR}/node-${version}-SHASUMS256.txt"
  curl -fsSL "https://nodejs.org/dist/v${version}/SHASUMS256.txt" >"${file}"
  python3 - "${file}" "${version}" <<'PY'
import sys

path, version = sys.argv[1:3]
wanted = {
    f"node-v{version}-linux-x64.tar.xz": "amd64",
    f"node-v{version}-linux-arm64.tar.xz": "arm64",
}
found = {}
for line in open(path):
    parts = line.split()
    if len(parts) == 2 and parts[1] in wanted:
        found[wanted[parts[1]]] = parts[0]
print(found.get("amd64", ""), found.get("arm64", ""))
PY
}

bun_checksums() { # <tag> -> "<amd64> <arm64>"
  local tag="$1"
  local file="${TMP_DIR}/${tag}-SHASUMS256.txt"
  curl -fsSL "https://github.com/oven-sh/bun/releases/download/${tag}/SHASUMS256.txt" >"${file}"
  python3 - "${file}" <<'PY'
import sys

wanted = {"bun-linux-x64.zip": "amd64", "bun-linux-aarch64.zip": "arm64"}
found = {}
for line in open(sys.argv[1]):
    parts = line.split()
    if len(parts) == 2 and parts[1] in wanted:
        found[wanted[parts[1]]] = parts[0]
print(found.get("amd64", ""), found.get("arm64", ""))
PY
}

liberica_checksums() { # <tag> -> "<amd64> <arm64>"
  local tag="$1"
  local checksums amd64 arm64

  checksums="$(python3 - "${TMP_DIR}/liberica.json" "${tag}" <<'PY'
import json
import sys

releases = json.load(open(sys.argv[1]))
tag = sys.argv[2]
assets = {}
for release in releases:
    if release.get("tag_name") == tag:
        assets = {asset["name"]: asset for asset in release.get("assets", [])}
        break

out = []
for arch in ("amd64", "aarch64"):
    asset = assets.get(f"bellsoft-jre{tag}-linux-{arch}.tar.gz") or {}
    digest = asset.get("digest") or ""
    out.append(digest[len("sha256:"):] if digest.startswith("sha256:") else "")
print(" ".join(out))
PY
)"

  amd64="${checksums%% *}"
  arm64="${checksums##* }"

  # Older releases may not expose a digest in the API; hash the tarball instead.
  if [[ -z "${amd64}" ]]; then
    amd64="$(curl -fsSL "https://github.com/bell-sw/Liberica/releases/download/${tag}/bellsoft-jre${tag}-linux-amd64.tar.gz" | sha256sum | cut -d' ' -f1)"
  fi
  if [[ -z "${arm64}" ]]; then
    arm64="$(curl -fsSL "https://github.com/bell-sw/Liberica/releases/download/${tag}/bellsoft-jre${tag}-linux-aarch64.tar.gz" | sha256sum | cut -d' ' -f1)"
  fi

  printf '%s %s\n' "${amd64}" "${arm64}"
}

get_arg() { # <file> <name>
  sed -n "s/^ARG ${2}=//p" "$1" | head -n 1
}

set_arg() { # <file> <name> <value>
  python3 - "$1" "$2" "$3" <<'PY'
import re
import sys

path, name, value = sys.argv[1:4]
with open(path) as handle:
    text = handle.read()

pattern = re.compile(rf"^ARG {re.escape(name)}=.*$", re.MULTILINE)
updated, count = pattern.subn(f"ARG {name}={value}", text)
if count != 1:
    sys.exit(f"error: expected exactly one ARG {name}= line in {path}, found {count}")

with open(path, "w") as handle:
    handle.write(updated)
PY
}

need() { # <description> <value>
  if [[ -z "$2" ]]; then
    printf 'error: could not resolve %s\n' "$1" >&2
    exit 1
  fi
}

mapfile -t dockerfiles < <(find . -name Dockerfile -not -path './.git/*' | sort)

printf '\n%-7s %-44s %-9s %-16s %-16s\n' "STATUS" "DOCKERFILE" "RUNTIME" "CURRENT" "LATEST"
printf '%s\n' "-------------------------------------------------------------------------------------------------"

updates=0
for file in "${dockerfiles[@]}"; do
  rel="${file#./}"
  comp=""
  cur=""
  latest=""
  tag=""
  channel=""

  if cur="$(get_arg "${file}" CHISEL_VERSION)"; [ -n "${cur}" ]; then
    comp="chisel"
    latest="${CHISEL_LATEST}"
  elif cur="$(get_arg "${file}" BUN_VERSION)"; [ -n "${cur}" ]; then
    comp="bun"
    tag="$(bun_latest "${cur%%.*}")"
    latest="${tag#bun-v}"
  elif cur="$(get_arg "${file}" NODE_VERSION)"; [ -n "${cur}" ]; then
    comp="nodejs"
    latest="$(node_latest "${cur%%.*}")"
  elif cur="$(get_arg "${file}" LIBERICA_VERSION)"; [ -n "${cur}" ]; then
    comp="java"
    latest="$(liberica_latest "${cur%%[!0-9]*}")"
  elif cur="$(get_arg "${file}" DOTNET_VERSION)"; [ -n "${cur}" ]; then
    comp="dotnet"
    channel="${cur%.*}"
    latest="$(dotnet_latest "${channel}")"
  elif cur="$(get_arg "${file}" ASPNET_VERSION)"; [ -n "${cur}" ]; then
    comp="aspnet"
    channel="${cur%.*}"
    latest="$(dotnet_latest "${channel}")"
  else
    continue
  fi

  need "the latest ${comp} version for ${rel}" "${latest}"

  if [[ "${latest}" == "${cur}" ]]; then
    printf '%-7s %-44s %-9s %-16s %-16s\n' "ok" "${rel}" "${comp}" "${cur}" "${latest}"
    continue
  fi

  updates=$((updates + 1))
  printf '%-7s %-44s %-9s %-16s %-16s\n' "update" "${rel}" "${comp}" "${cur}" "${latest}"

  if [[ "${APPLY}" != true ]]; then
    continue
  fi

  case "${comp}" in
    chisel)
      set_arg "${file}" CHISEL_VERSION "${latest}"
      ;;
    nodejs)
      read -r sha_amd64 sha_arm64 <<<"$(node_checksums "${latest}")"
      need "the Node.js ${latest} checksums" "${sha_amd64}${sha_arm64}"
      set_arg "${file}" NODE_VERSION "${latest}"
      set_arg "${file}" NODE_SHA256_AMD64 "${sha_amd64}"
      set_arg "${file}" NODE_SHA256_ARM64 "${sha_arm64}"
      ;;
    bun)
      read -r sha_amd64 sha_arm64 <<<"$(bun_checksums "${tag}")"
      need "the Bun ${latest} checksums" "${sha_amd64}${sha_arm64}"
      set_arg "${file}" BUN_VERSION "${latest}"
      set_arg "${file}" BUN_SHA256_AMD64 "${sha_amd64}"
      set_arg "${file}" BUN_SHA256_ARM64 "${sha_arm64}"
      ;;
    java)
      read -r sha_amd64 sha_arm64 <<<"$(liberica_checksums "${latest}")"
      need "the Liberica ${latest} checksums" "${sha_amd64}${sha_arm64}"
      set_arg "${file}" LIBERICA_VERSION "${latest}"
      set_arg "${file}" LIBERICA_SHA256_AMD64 "${sha_amd64}"
      set_arg "${file}" LIBERICA_SHA256_ARM64 "${sha_arm64}"
      ;;
    dotnet)
      read -r sha_amd64 sha_arm64 <<<"$(dotnet_checksums "${channel}" "${latest}" runtime)"
      need "the .NET ${latest} checksums" "${sha_amd64}${sha_arm64}"
      set_arg "${file}" DOTNET_VERSION "${latest}"
      set_arg "${file}" DOTNET_SHA512_AMD64 "${sha_amd64}"
      set_arg "${file}" DOTNET_SHA512_ARM64 "${sha_arm64}"
      ;;
    aspnet)
      read -r sha_amd64 sha_arm64 <<<"$(dotnet_checksums "${channel}" "${latest}" aspnetcore-runtime)"
      need "the ASP.NET Core ${latest} checksums" "${sha_amd64}${sha_arm64}"
      set_arg "${file}" ASPNET_VERSION "${latest}"
      set_arg "${file}" ASPNET_SHA512_AMD64 "${sha_amd64}"
      set_arg "${file}" ASPNET_SHA512_ARM64 "${sha_arm64}"
      ;;
  esac
done

printf '\n'
if ((updates == 0)); then
  printf 'All pinned versions are up to date.\n'
  exit 0
fi

if [[ "${APPLY}" == true ]]; then
  printf '%d update(s) applied.\n' "${updates}"
  exit 0
fi

printf '%d update(s) available.\n' "${updates}"
exit 1
