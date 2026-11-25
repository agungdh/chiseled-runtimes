#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: aspnet.sh <image> [platform]}"
platform="${2:-linux/amd64}"

runtimes="$(docker run --rm --platform "$platform" "$image" dotnet --list-runtimes)"
printf '%s\n' "${runtimes}"
grep -q 'Microsoft.NETCore.App' <<< "${runtimes}"
grep -q 'Microsoft.AspNetCore.App' <<< "${runtimes}"
docker run --rm --platform "$platform" "$image" dotnet --info
