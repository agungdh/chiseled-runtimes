#!/usr/bin/env bash
set -euo pipefail

# Check the pinned runtime versions in every Dockerfile against upstream.
# This script only reports; it never modifies any file.
#
# Usage:
#   ./scripts/check-updates.sh
#   ./scripts/check-updates.sh --help
#
# Exit status:
#   0  all pinned versions are up to date
#   1  one or more updates are available
#   2  usage error
#
# Sources:
#   chisel   -> latest stable release on GitHub (canonical/chisel)
#   Bun      -> latest stable Bun <major> release on GitHub (oven-sh/bun)
#   Node.js  -> latest release of the same major from nodejs.org/dist/index.json
#   Java     -> latest Liberica release for the same feature version that ships
#               a plain JRE tarball (bell-sw/Liberica); CRaC-only builds skipped
#
# Set GITHUB_TOKEN (or GH_TOKEN) to raise the GitHub API rate limit.

usage() {
  sed -n '4,23p' "$0" | sed -E 's/^# ?//'
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

case "${1:-}" in
  "") ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf 'error: unknown argument %s (this script only checks; no options to apply)\n' "${1}" >&2
    usage >&2
    exit 2
    ;;
esac

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

get_arg() { # <file> <name>
  sed -n "s/^ARG ${2}=//p" "$1" | head -n 1
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

  if cur="$(get_arg "${file}" CHISEL_VERSION)"; [ -n "${cur}" ]; then
    comp="chisel"
    latest="${CHISEL_LATEST}"
  elif cur="$(get_arg "${file}" BUN_VERSION)"; [ -n "${cur}" ]; then
    comp="bun"
    latest="$(bun_latest "${cur%%.*}")"
    latest="${latest#bun-v}"
  elif cur="$(get_arg "${file}" NODE_VERSION)"; [ -n "${cur}" ]; then
    comp="nodejs"
    latest="$(node_latest "${cur%%.*}")"
  elif cur="$(get_arg "${file}" LIBERICA_VERSION)"; [ -n "${cur}" ]; then
    comp="java"
    latest="$(liberica_latest "${cur%%[!0-9]*}")"
  else
    continue
  fi

  need "the latest ${comp} version for ${rel}" "${latest}"

  if [[ "${latest}" == "${cur}" ]]; then
    printf '%-7s %-44s %-9s %-16s %-16s\n' "ok" "${rel}" "${comp}" "${cur}" "${latest}"
  else
    updates=$((updates + 1))
    printf '%-7s %-44s %-9s %-16s %-16s\n' "update" "${rel}" "${comp}" "${cur}" "${latest}"
  fi
done

printf '\n'
if ((updates == 0)); then
  printf 'All pinned versions are up to date.\n'
  exit 0
fi

printf '%d update(s) available.\n' "${updates}"
exit 1
