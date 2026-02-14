#!/usr/bin/env python3
"""Update pinned release version/hash values in a Nix file.

Usage:
  update-pins.py <project> <nix_file>
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

DEFAULT_LOOKBACK = 10


@dataclass(frozen=True)
class AssetSpec:
    asset_name: str
    binary_name: str


@dataclass(frozen=True)
class ProjectConfig:
    repo: str
    tag_regex: str
    version_var: str
    binary_key: str
    assets: dict[str, AssetSpec]


PROJECTS = {
    "codex": ProjectConfig(
        repo="openai/codex",
        tag_regex=r"^rust-v(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)$",
        version_var="codexVersion",
        binary_key="binaryName",
        assets={
            "x86_64-linux": AssetSpec(
                asset_name="codex-x86_64-unknown-linux-musl.tar.gz",
                binary_name="codex-x86_64-unknown-linux-musl",
            ),
            "aarch64-darwin": AssetSpec(
                asset_name="codex-aarch64-apple-darwin.tar.gz",
                binary_name="codex-aarch64-apple-darwin",
            ),
        },
    ),
}


def github_headers() -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "release-pin-updater",
    }
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def read_json(url: str) -> Any:
    request = urllib.request.Request(url, headers=github_headers())
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def parse_repo(repo: str) -> tuple[str, str]:
    if "/" not in repo:
        raise ValueError(f"Invalid --repo '{repo}'. Expected format 'owner/name'.")
    owner, name = repo.split("/", 1)
    if not owner or not name:
        raise ValueError(f"Invalid --repo '{repo}'. Expected format 'owner/name'.")
    return owner, name


def parse_numeric_version(version_text: str) -> tuple[int, ...]:
    core, _, _ = version_text.partition("-")
    try:
        return tuple(int(part) for part in core.split("."))
    except ValueError as exc:
        raise ValueError(f"Tag version '{version_text}' is not numeric dotted form.") from exc


def parse_prerelease_identifiers(version_text: str) -> tuple[tuple[int, int | str], ...]:
    _, sep, prerelease = version_text.partition("-")
    if not sep:
        return ()
    identifiers: list[tuple[int, int | str]] = []
    for identifier in prerelease.split("."):
        if identifier.isdigit():
            identifiers.append((0, int(identifier)))
        else:
            identifiers.append((1, identifier))
    return tuple(identifiers)


def latest_release(
    releases: list[dict[str, Any]],
    tag_pattern: re.Pattern[str],
    include_prerelease: bool,
) -> tuple[str, str, dict[str, Any]]:
    candidates: list[tuple[tuple[int, ...], int, tuple[tuple[int, int | str], ...], str, str, dict[str, Any]]] = []
    for release in releases:
        if release.get("draft"):
            continue
        if release.get("prerelease") and not include_prerelease:
            continue

        tag = release.get("tag_name", "")
        match = tag_pattern.match(tag)
        if not match:
            continue

        version_text = match.group(1) if match.groups() else match.group(0)
        try:
            numeric = parse_numeric_version(version_text)
        except ValueError:
            continue
        prerelease_identifiers = parse_prerelease_identifiers(version_text)
        # Stable releases sort above prereleases for the same numeric core.
        stable_rank = 1 if not prerelease_identifiers else 0
        candidates.append(
            (
                numeric,
                stable_rank,
                prerelease_identifiers,
                version_text,
                tag,
                release,
            )
        )

    if not candidates:
        release_type = "stable/prerelease" if include_prerelease else "stable"
        raise RuntimeError(f"No matching {release_type} releases found for the provided --tag-regex.")

    _, _, _, version, tag, release = max(candidates, key=lambda item: (item[0], item[1], item[2]))
    return version, tag, release


def sha256_hex_to_sri(hex_digest: str) -> str:
    if not re.fullmatch(r"[0-9a-fA-F]{64}", hex_digest):
        raise RuntimeError(f"Invalid sha256 hex digest: {hex_digest}")
    return "sha256-" + base64.b64encode(bytes.fromhex(hex_digest)).decode("ascii")


def release_digest_to_sri(asset_name: str, digest: str) -> str:
    if not digest:
        raise RuntimeError(
            f"Missing digest for asset '{asset_name}'. "
            "GitHub release did not provide a digest value."
        )

    if digest.startswith("sha256:"):
        return sha256_hex_to_sri(digest.split(":", 1)[1])
    if digest.startswith("sha256-"):
        return digest

    raise RuntimeError(
        f"Unsupported digest format for asset '{asset_name}': {digest}. "
        "Expected 'sha256:<hex>' or 'sha256-<base64>'."
    )


def replace_version(text: str, version_var: str, version_value: str) -> str:
    pattern = re.compile(rf'({re.escape(version_var)}\s*=\s*")[^"]+(";)')
    updated, count = pattern.subn(rf"\g<1>{version_value}\2", text, count=1)
    if count != 1:
        raise RuntimeError(f"Could not locate version assignment for '{version_var}'.")
    return updated


def replace_assignment(
    block_text: str,
    key: str,
    new_value: str,
    entry_key: str,
) -> str:
    pattern = re.compile(rf'({re.escape(key)}\s*=\s*")[^"]*(";)')
    updated, count = pattern.subn(rf"\g<1>{new_value}\2", block_text, count=1)
    if count != 1:
        raise RuntimeError(f"Could not locate key '{key}' inside stanza '{entry_key}'.")
    return updated


def update_asset_stanza(
    text: str,
    entry_key: str,
    binary_key: str,
    new_url: str,
    new_hash: str,
    new_binary_name: str,
) -> str:
    pattern = re.compile(rf"({re.escape(entry_key)}\s*=\s*\{{)([\s\S]*?)(\n\s*\}};)")
    match = pattern.search(text)
    if not match:
        raise RuntimeError(f"Could not locate stanza for entry_key='{entry_key}'.")

    block_body = match.group(2)
    block_body = replace_assignment(block_body, "url", new_url, entry_key)
    block_body = replace_assignment(block_body, "hash", new_hash, entry_key)
    block_body = replace_assignment(block_body, binary_key, new_binary_name, entry_key)

    return text[: match.start(2)] + block_body + text[match.end(2) :]


def build_tag_expression(tag: str, version: str, version_var: str) -> str:
    if version not in tag:
        raise RuntimeError(f"Version '{version}' not found in release tag '{tag}'.")
    return tag.replace(version, f"${{{version_var}}}", 1)


def update_file(
    file_path: Path,
    project_config: ProjectConfig,
    version_value: str,
    tag: str,
    repo: str,
    hashes: dict[str, str],
    dry_run: bool,
) -> None:
    original = file_path.read_text(encoding="utf-8")
    updated = replace_version(original, project_config.version_var, version_value)
    tag_expression = build_tag_expression(tag, version_value, project_config.version_var)
    for entry_key, new_hash in hashes.items():
        spec = project_config.assets[entry_key]
        updated = update_asset_stanza(
            updated,
            entry_key=entry_key,
            binary_key=project_config.binary_key,
            new_url=f"https://github.com/{repo}/releases/download/{tag_expression}/{spec.asset_name}",
            new_hash=new_hash,
            new_binary_name=spec.binary_name,
        )

    if dry_run:
        print(f"[dry-run] Would update {file_path}")
    elif updated != original:
        file_path.write_text(updated, encoding="utf-8")
        print(f"Updated {file_path}")
    else:
        print(f"No changes needed in {file_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Update pinned version/hash values for a configured project."
    )
    parser.add_argument(
        "project",
        help=f"Project key ({', '.join(sorted(PROJECTS.keys()))})",
    )
    parser.add_argument(
        "file",
        type=Path,
        help="Target Nix file to update.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print updates without writing files.",
    )
    parser.add_argument(
        "--pre-release",
        action="store_true",
        help="Allow prerelease versions when selecting the latest release.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    project_config = PROJECTS.get(args.project)
    if project_config is None:
        known_projects = ", ".join(sorted(PROJECTS.keys()))
        print(f"Unknown project '{args.project}'. Known projects: {known_projects}", file=sys.stderr)
        return 1

    if not args.file.exists():
        print(f"File not found: {args.file}", file=sys.stderr)
        return 1

    try:
        owner, repo_name = parse_repo(project_config.repo)
        tag_pattern = re.compile(project_config.tag_regex)
    except (ValueError, re.error) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    releases_url = (
        f"https://api.github.com/repos/{owner}/{repo_name}/releases?per_page={DEFAULT_LOOKBACK}"
    )
    releases = read_json(releases_url)
    if not isinstance(releases, list):
        print("Unexpected GitHub API response for releases.", file=sys.stderr)
        return 1

    try:
        version, tag, release = latest_release(
            releases,
            tag_pattern,
            include_prerelease=args.pre_release,
        )
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    assets = {asset["name"]: asset for asset in release.get("assets", []) if "name" in asset}

    print(f"Latest release: {tag}")
    hashes: dict[str, str] = {}
    for entry_key, spec in project_config.assets.items():
        asset = assets.get(spec.asset_name)
        if not asset:
            print(
                f"Missing asset '{spec.asset_name}' in release '{release.get('tag_name')}'.",
                file=sys.stderr,
            )
            return 1
        print(f"Reading digest for {spec.asset_name} ...")
        try:
            hashes[entry_key] = release_digest_to_sri(spec.asset_name, str(asset.get("digest", "")))
        except RuntimeError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        print(f"  {entry_key}: {hashes[entry_key]}")

    try:
        update_file(
            file_path=args.file,
            project_config=project_config,
            version_value=version,
            tag=tag,
            repo=project_config.repo,
            hashes=hashes,
            dry_run=args.dry_run,
        )
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
