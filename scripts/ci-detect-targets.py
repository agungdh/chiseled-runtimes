#!/usr/bin/env python3
"""Detect which container image targets need to be (re)built.

Targets are discovered from the repository layout:

    base/ubuntu-<release>/Dockerfile            -> common base image
    base/<runtime>-ubuntu-<release>/Dockerfile  -> language base image
    <runtime>/<version>-ubuntu<release>/        -> runtime image

Every target is built once per architecture on a native GitHub runner, then the
per-architecture images are merged into one multi-arch manifest. No QEMU is
used: amd64 jobs run on `ubuntu-26.04` and arm64 jobs on `ubuntu-26.04-arm`.

A target is rebuilt when any file inside its directory changes. A language base
is also rebuilt when the common base for its Ubuntu release changes, and a
runtime is rebuilt when either its language base or the common base changes.
ASP.NET Core runtime images reuse the .NET language base (see
LANG_BASE_ALIASES) because both need the same native dependencies.
Changes under .github/ rebuild everything, while changes elsewhere (README,
scripts, ...) rebuild nothing.

Environment:
    GITHUB_EVENT_NAME   push | pull_request | workflow_dispatch | ...
    BEFORE_SHA          push: commit before the push
    PR_BASE_SHA         pull_request: base commit
    PR_HEAD_SHA         pull_request: head commit
    REGISTRY            image registry (default: ghcr.io)
    IMAGE_NAMESPACE     image namespace (default: agungdh/chiseled-runtimes)
    REVISION            git revision used in build tags (default: unknown)
    BUILD_STAMP         unique build timestamp used in build tags
    LATEST_TARGETS      space-separated contexts that also get :latest
    RUNNER_AMD64        runner label for amd64 (default: ubuntu-26.04)
    RUNNER_ARM64        runner label for arm64 (default: ubuntu-26.04-arm)
    GITHUB_OUTPUT       file to append the job outputs to
    CHANGED_FILES       optional newline-separated override, for local testing

Outputs (JSON arrays, written to GITHUB_OUTPUT):
    base_builds         per-arch common base image builds
    base_merges         multi-arch common base manifests to create
    lang_base_builds    per-arch language base image builds
    lang_base_merges    multi-arch language base manifests to create
    runtime_builds      per-arch runtime image builds
    runtime_merges      multi-arch runtime manifests to create
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ARCHES = (
    {
        "arch": "amd64",
        "platform": "linux/amd64",
        "env": "RUNNER_AMD64",
        "default_runner": "ubuntu-26.04",
    },
    {
        "arch": "arm64",
        "platform": "linux/arm64",
        "env": "RUNNER_ARM64",
        "default_runner": "ubuntu-26.04-arm",
    },
)

# ASP.NET Core is part of the .NET platform and needs the same native
# dependencies, so its runtime images reuse the .NET language base instead of
# carrying an identical copy of it.
LANG_BASE_ALIASES = {"aspnet": "dotnet"}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def changed_files() -> list[str] | None:
    """Return changed paths, or None when everything should be rebuilt."""
    override = os.environ.get("CHANGED_FILES")
    if override is not None:
        return [line.strip() for line in override.splitlines() if line.strip()]

    event = os.environ.get("GITHUB_EVENT_NAME", "")

    if event == "workflow_dispatch":
        return None

    if event == "pull_request":
        base = os.environ.get("PR_BASE_SHA", "")
        head = os.environ.get("PR_HEAD_SHA", "HEAD")
        if not base:
            return None
        try:
            merge_base = git("merge-base", base, head)
            return _split(git("diff", "--name-only", merge_base, head))
        except subprocess.CalledProcessError:
            try:
                return _split(git("diff", "--name-only", base, head))
            except subprocess.CalledProcessError:
                return None

    # Push (and anything else that provides a "before" SHA).
    before = os.environ.get("BEFORE_SHA", "")
    if not before or set(before) == {"0"}:
        return None
    try:
        git("rev-parse", "--verify", f"{before}^{{commit}}")
        return _split(git("diff", "--name-only", before, "HEAD"))
    except subprocess.CalledProcessError:
        return None


def _split(output: str) -> list[str]:
    return [line for line in output.splitlines() if line]


def discover_common_bases() -> dict[str, str]:
    """Map Ubuntu release -> directory, e.g. {"26.04": "base/ubuntu-26.04"}."""
    bases: dict[str, str] = {}
    base_dir = ROOT / "base"
    if not base_dir.is_dir():
        return bases
    for path in sorted(base_dir.iterdir()):
        if not path.is_dir() or not path.name.startswith("ubuntu-"):
            continue
        if not (path / "Dockerfile").is_file():
            continue
        version = path.name.removeprefix("ubuntu-")
        if version:
            bases[version] = path.relative_to(ROOT).as_posix()
    return bases


def discover_lang_bases() -> dict[tuple[str, str], str]:
    """Map (runtime, Ubuntu release) -> directory, e.g. ("java", "26.04")."""
    bases: dict[tuple[str, str], str] = {}
    base_dir = ROOT / "base"
    if not base_dir.is_dir():
        return bases
    for path in sorted(base_dir.iterdir()):
        if not path.is_dir() or path.name.startswith("ubuntu-"):
            continue
        if "-ubuntu-" not in path.name:
            continue
        if not (path / "Dockerfile").is_file():
            continue
        runtime, version = path.name.split("-ubuntu-", 1)
        if runtime and version:
            bases[(runtime, version)] = path.relative_to(ROOT).as_posix()
    return bases


def discover_runtimes() -> dict[str, dict[str, str]]:
    """Map target directory (e.g. "java/25-ubuntu26.04") -> target metadata."""
    runtimes: dict[str, dict[str, str]] = {}
    for runtime_dir in sorted(ROOT.iterdir()):
        if not runtime_dir.is_dir() or runtime_dir.name.startswith("."):
            continue
        if runtime_dir.name in {"base", "scripts"}:
            continue
        for target_dir in sorted(runtime_dir.iterdir()):
            if not target_dir.is_dir() or not (target_dir / "Dockerfile").is_file():
                continue
            if "-ubuntu" not in target_dir.name:
                continue
            version, ubuntu = target_dir.name.split("-ubuntu", 1)
            if not version or not ubuntu:
                continue
            context = target_dir.relative_to(ROOT).as_posix()
            runtimes[context] = {
                "runtime": runtime_dir.name,
                "tag": target_dir.name,
                "version": version,
                "ubuntu": ubuntu,
                "context": context,
            }
    return runtimes


def arch_entries() -> list[dict[str, str]]:
    entries = []
    for arch in ARCHES:
        entries.append(
            {
                "arch": arch["arch"],
                "platform": arch["platform"],
                "runner": os.environ.get(arch["env"], arch["default_runner"]),
            }
        )
    return entries


def sources_for(repository: str, tag: str) -> list[str]:
    return [f"{repository}:{tag}-{arch['arch']}" for arch in ARCHES]


def main() -> int:
    registry = os.environ.get("REGISTRY", "ghcr.io")
    namespace = os.environ.get("IMAGE_NAMESPACE", "agungdh/chiseled-runtimes")
    revision = os.environ.get("REVISION", "unknown")
    stamp = os.environ.get("BUILD_STAMP", "unknown")
    latest_targets = set(os.environ.get("LATEST_TARGETS", "").split())

    common_bases = discover_common_bases()
    lang_bases = discover_lang_bases()
    runtimes = discover_runtimes()

    changed = changed_files()
    rebuild_all = changed is None
    changed_set = set(changed or [])

    if not rebuild_all and any(path.startswith(".github/") for path in changed_set):
        rebuild_all = True

    changed_common = {
        ubuntu
        for ubuntu, context in common_bases.items()
        if rebuild_all or any(path.startswith(context + "/") for path in changed_set)
    }

    changed_lang = {
        key
        for key, context in lang_bases.items()
        if rebuild_all
        or key[1] in changed_common
        or any(path.startswith(context + "/") for path in changed_set)
    }

    base_repository = f"{registry}/{namespace}/base"

    base_builds = []
    base_merges = []
    for ubuntu in sorted(changed_common):
        tag = f"ubuntu-{ubuntu}"
        unique_tag = f"{tag}-{revision}-{stamp}"

        for arch in arch_entries():
            base_builds.append(
                {
                    "ubuntu": ubuntu,
                    "tag": tag,
                    "context": common_bases[ubuntu],
                    "repository": base_repository,
                    "image": f"{base_repository}:{tag}-{arch['arch']}",
                    "push_tags": [f"{tag}-{arch['arch']}", f"{unique_tag}-{arch['arch']}"],
                    "arch": arch["arch"],
                    "platform": arch["platform"],
                    "runner": arch["runner"],
                }
            )

        base_merges.append(
            {
                "kind": "base",
                "ubuntu": ubuntu,
                "tag": tag,
                "context": common_bases[ubuntu],
                "repository": base_repository,
                "sources": sources_for(base_repository, tag),
                "tags": [tag, unique_tag],
            }
        )

    lang_base_builds = []
    lang_base_merges = []
    for runtime, ubuntu in sorted(changed_lang):
        tag = f"{runtime}-ubuntu-{ubuntu}"
        unique_tag = f"{tag}-{revision}-{stamp}"

        for arch in arch_entries():
            lang_base_builds.append(
                {
                    "runtime": runtime,
                    "ubuntu": ubuntu,
                    "tag": tag,
                    "context": lang_bases[(runtime, ubuntu)],
                    "repository": base_repository,
                    "image": f"{base_repository}:{tag}-{arch['arch']}",
                    "push_tags": [f"{tag}-{arch['arch']}", f"{unique_tag}-{arch['arch']}"],
                    "arch": arch["arch"],
                    "platform": arch["platform"],
                    "runner": arch["runner"],
                    "common_base_image": f"{base_repository}:ubuntu-{ubuntu}",
                    "common_base_context": common_bases[ubuntu],
                    "common_changed": ubuntu in changed_common,
                }
            )

        lang_base_merges.append(
            {
                "kind": "lang_base",
                "runtime": runtime,
                "ubuntu": ubuntu,
                "tag": tag,
                "context": lang_bases[(runtime, ubuntu)],
                "repository": base_repository,
                "sources": sources_for(base_repository, tag),
                "tags": [tag, unique_tag],
            }
        )

    runtime_builds = []
    runtime_merges = []
    for context, target in sorted(runtimes.items()):
        base_runtime = LANG_BASE_ALIASES.get(target["runtime"], target["runtime"])
        key = (base_runtime, target["ubuntu"])
        if target["ubuntu"] not in common_bases:
            print(
                f"error: {context} depends on missing base ubuntu-{target['ubuntu']!r}",
                file=sys.stderr,
            )
            return 1
        if key not in lang_bases:
            print(
                f"error: {context} depends on missing language base "
                f"{base_runtime}-ubuntu-{target['ubuntu']!r}",
                file=sys.stderr,
            )
            return 1

        base_changed = key in changed_lang
        runtime_changed = rebuild_all or any(
            path.startswith(context + "/") for path in changed_set
        )
        if not (base_changed or runtime_changed):
            continue

        tag = target["tag"]
        unique_tag = f"{tag}-{revision}-{stamp}"
        repository = f"{registry}/{namespace}/{target['runtime']}"
        tags = [tag, unique_tag]
        if target["version"] != tag:
            tags.append(target["version"])
        if context in latest_targets:
            tags.append("latest")

        for arch in arch_entries():
            runtime_builds.append(
                {
                    **target,
                    "base_changed": base_changed,
                    "base_context": lang_bases[key],
                    "base_image": f"{base_repository}:{base_runtime}-ubuntu-{target['ubuntu']}",
                    "common_changed": target["ubuntu"] in changed_common,
                    "common_base_image": f"{base_repository}:ubuntu-{target['ubuntu']}",
                    "common_base_context": common_bases[target["ubuntu"]],
                    "repository": repository,
                    "image": f"{repository}:{tag}-{arch['arch']}",
                    "push_tags": [f"{pushed}-{arch['arch']}" for pushed in tags],
                    "arch": arch["arch"],
                    "platform": arch["platform"],
                    "runner": arch["runner"],
                }
            )

        runtime_merges.append(
            {
                "kind": "runtime",
                **target,
                "repository": repository,
                "sources": sources_for(repository, tag),
                "tags": tags,
            }
        )

    print(f"changed files: {len(changed_set) if changed is not None else 'all'}")
    print(f"base builds:      {[e['image'] for e in base_builds]}")
    print(f"base merges:      {[e['repository'] + ':' + e['tag'] for e in base_merges]}")
    print(f"lang base builds: {[e['image'] for e in lang_base_builds]}")
    print(
        "lang base merges: "
        f"{[e['repository'] + ':' + e['tag'] for e in lang_base_merges]}"
    )
    print(f"runtime builds:   {[e['image'] for e in runtime_builds]}")
    print(f"runtime merges:   {[e['repository'] + ':' + e['tag'] for e in runtime_merges]}")

    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as handle:
            handle.write(f"base_builds={json.dumps(base_builds, separators=(',', ':'))}\n")
            handle.write(f"base_merges={json.dumps(base_merges, separators=(',', ':'))}\n")
            handle.write(
                "lang_base_builds="
                f"{json.dumps(lang_base_builds, separators=(',', ':'))}\n"
            )
            handle.write(
                "lang_base_merges="
                f"{json.dumps(lang_base_merges, separators=(',', ':'))}\n"
            )
            handle.write(
                f"runtime_builds={json.dumps(runtime_builds, separators=(',', ':'))}\n"
            )
            handle.write(
                f"runtime_merges={json.dumps(runtime_merges, separators=(',', ':'))}\n"
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
