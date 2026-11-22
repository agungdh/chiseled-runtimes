#!/usr/bin/env python3
"""Detect which container image targets need to be (re)built.

Targets are discovered from the repository layout:

    base/ubuntu-<release>/Dockerfile          -> base image
    <runtime>/<version>-ubuntu<release>/       -> runtime image

A target is rebuilt when any file inside its directory changes. A runtime is
also rebuilt when the Ubuntu base it depends on changes. Changes under
.github/ rebuild everything, while changes elsewhere (README, scripts, ...)
rebuild nothing.

Environment:
    GITHUB_EVENT_NAME   push | pull_request | workflow_dispatch | ...
    BEFORE_SHA          push: commit before the push
    PR_BASE_SHA         pull_request: base commit
    PR_HEAD_SHA         pull_request: head commit
    REGISTRY            image registry (default: ghcr.io)
    IMAGE_NAMESPACE     image namespace (default: agungdh/chiseled-runtimes)
    GITHUB_OUTPUT       file to append the `bases` and `runtimes` outputs to
    CHANGED_FILES       optional newline-separated override, for local testing

Outputs (JSON arrays, written to GITHUB_OUTPUT):
    bases     base images that changed
    runtimes  runtime images that changed or depend on a changed base
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


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


def discover_bases() -> dict[str, str]:
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


def main() -> int:
    registry = os.environ.get("REGISTRY", "ghcr.io")
    namespace = os.environ.get("IMAGE_NAMESPACE", "agungdh/chiseled-runtimes")

    bases = discover_bases()
    runtimes = discover_runtimes()

    changed = changed_files()
    rebuild_all = changed is None
    changed_set = set(changed or [])

    if not rebuild_all and any(path.startswith(".github/") for path in changed_set):
        rebuild_all = True

    changed_bases = {
        ubuntu
        for ubuntu, context in bases.items()
        if rebuild_all or any(path.startswith(context + "/") for path in changed_set)
    }

    base_entries = [
        {
            "ubuntu": ubuntu,
            "context": bases[ubuntu],
            "image": f"{registry}/{namespace}/base:ubuntu-{ubuntu}",
        }
        for ubuntu in sorted(changed_bases)
    ]

    runtime_entries = []
    for context, target in sorted(runtimes.items()):
        if target["ubuntu"] not in bases:
            print(
                f"error: {context} depends on missing base {target['ubuntu']!r}",
                file=sys.stderr,
            )
            return 1

        base_changed = rebuild_all or target["ubuntu"] in changed_bases
        runtime_changed = rebuild_all or any(
            path.startswith(context + "/") for path in changed_set
        )
        if not (base_changed or runtime_changed):
            continue

        runtime_entries.append(
            {
                **target,
                "base_changed": base_changed,
                "base_context": bases[target["ubuntu"]],
                "base_image": f"{registry}/{namespace}/base:ubuntu-{target['ubuntu']}",
                "image": f"{registry}/{namespace}/{target['runtime']}:{target['tag']}",
            }
        )

    print(f"changed files: {len(changed_set) if changed is not None else 'all'}")
    print(f"bases:    {[e['image'] for e in base_entries]}")
    print(f"runtimes: {[e['image'] for e in runtime_entries]}")

    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as handle:
            handle.write(f"bases={json.dumps(base_entries, separators=(',', ':'))}\n")
            handle.write(
                f"runtimes={json.dumps(runtime_entries, separators=(',', ':'))}\n"
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
