#!/usr/bin/env python3
import os
import re
import sys
from datetime import datetime
from pathlib import Path
import subprocess


KNOWN_SECTIONS = [
    "Purpose",
    "Working Agreements",
    "Top Rules",
    "User Preferences",
    "Session Index",
    "Log",
]

TIMESTAMP_RE = re.compile(r"^###\s+([0-9T:\-+.Z]+)\s+\|")


def read_lines(path: Path) -> list[str] | None:
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return None


def parse_sections(lines: list[str]) -> tuple[dict[str, list[str]], list[str]]:
    sections: dict[str, list[str]] = {}
    order: list[str] = []
    current: str | None = None
    for line in lines:
        if line.startswith("## "):
            current = line[3:].strip()
            sections[current] = []
            order.append(current)
            continue
        if current is not None:
            sections[current].append(line)
    return sections, order


def merge_blocks(dest: list[str], src: list[str]) -> list[str]:
    if not dest:
        return list(src)
    if not src:
        return list(dest)
    merged = list(dest)
    for line in src:
        if line not in merged:
            merged.append(line)
    return merged


def parse_session_ids(lines: list[str]) -> list[str]:
    ids: list[str] = []
    in_ids = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("- session_ids"):
            in_ids = True
            continue
        if stripped.startswith("- session_count"):
            continue
        if in_ids:
            if stripped.startswith("- "):
                ids.append(stripped[2:].strip())
                continue
            if stripped == "":
                continue
            in_ids = False
    return ids


def build_session_index(ids: list[str]) -> list[str]:
    lines = [
        f"- session_count: {len(ids)}",
        "- session_ids (newest first):",
    ]
    for entry in ids:
        lines.append(f"  - {entry}")
    return lines


def parse_timestamp(header: str) -> datetime | None:
    match = TIMESTAMP_RE.match(header)
    if not match:
        return None
    raw = match.group(1)
    if raw.endswith("Z"):
        raw = f"{raw[:-1]}+00:00"
    try:
        return datetime.fromisoformat(raw)
    except ValueError:
        return None


def normalize_entry(lines: list[str]) -> list[str]:
    trimmed = list(lines)
    while trimmed and trimmed[-1] == "":
        trimmed.pop()
    return trimmed


def parse_log_entries(lines: list[str]) -> list[tuple[datetime | None, list[str]]]:
    entries: list[tuple[datetime | None, list[str]]] = []
    current: list[str] = []
    current_ts: datetime | None = None
    for line in lines:
        if line.startswith("### "):
            if current:
                entries.append((current_ts, current))
            current = [line]
            current_ts = parse_timestamp(line)
            continue
        if current:
            current.append(line)
    if current:
        entries.append((current_ts, current))
    return entries


def merge_logs(dest: list[str], src: list[str]) -> list[str]:
    combined = parse_log_entries(dest) + parse_log_entries(src)
    seen: set[str] = set()
    unique: list[tuple[datetime | None, list[str]]] = []
    for ts, entry in combined:
        normalized = normalize_entry(entry)
        key = "\n".join(normalized)
        if key in seen:
            continue
        seen.add(key)
        unique.append((ts, normalized))
    with_dt = [(ts, entry) for ts, entry in unique if ts is not None]
    without_dt = [(ts, entry) for ts, entry in unique if ts is None]
    with_dt.sort(key=lambda item: item[0], reverse=True)
    merged = with_dt + without_dt
    out: list[str] = []
    for idx, (_ts, entry) in enumerate(merged):
        out.extend(entry)
        if idx != len(merged) - 1:
            out.append("")
    return out


def merge_extras(
    dest_sections: dict[str, list[str]],
    dest_order: list[str],
    src_sections: dict[str, list[str]],
    src_order: list[str],
) -> list[tuple[str, list[str]]]:
    extras: list[tuple[str, list[str]]] = []
    seen: set[str] = set()
    for title in dest_order:
        if title not in KNOWN_SECTIONS:
            extras.append((title, dest_sections.get(title, [])))
            seen.add(title)
    for title in src_order:
        if title not in KNOWN_SECTIONS and title not in seen:
            extras.append((title, src_sections.get(title, [])))
            seen.add(title)
    return extras


def build_notebook(
    merged: dict[str, list[str]], extras: list[tuple[str, list[str]]]
) -> str:
    out: list[str] = ["# Notebook", ""]
    for title in KNOWN_SECTIONS:
        out.append(f"## {title}")
        out.extend(merged.get(title, []))
        out.append("")
    for title, lines in extras:
        out.append(f"## {title}")
        out.extend(lines)
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def resolve_repo_root() -> Path:
    git_dir = Path(".git")
    if git_dir.exists():
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                check=True,
                capture_output=True,
                text=True,
            )
            return Path(result.stdout.strip())
        except Exception:
            pass
    return Path.cwd()


def resolve_repo_name(repo_root: Path) -> str:
    try:
        remote = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            check=True,
            capture_output=True,
            text=True,
            cwd=repo_root,
        ).stdout.strip()
        if remote:
            name = subprocess.run(
                ["basename", "-s", ".git", remote],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            if name:
                return name
    except Exception:
        pass
    return repo_root.name


def main() -> int:
    repo_root = resolve_repo_root()
    repo_name = resolve_repo_name(repo_root)
    cache_home = os.environ.get(
        "XDG_CACHE_HOME",
        os.path.join(Path.home(), ".cache"),
    )
    cache_root = Path(os.path.expanduser(cache_home))
    target_dir = Path(os.path.join(cache_root, "agents", repo_name))
    target_path = Path(os.path.join(target_dir, "notebook.md"))
    source_path = Path(os.path.join(repo_root, ".agents", "notebook.md"))

    source_lines = read_lines(source_path)
    if source_lines is None:
        print("No repo notebook found, nothing to migrate.")
        return 0

    dest_lines = read_lines(target_path) or []
    src_sections, src_order = parse_sections(source_lines)
    dest_sections, dest_order = parse_sections(dest_lines)

    merged: dict[str, list[str]] = {}
    merged["Purpose"] = merge_blocks(
        dest_sections.get("Purpose", []), src_sections.get("Purpose", [])
    )
    merged["Working Agreements"] = merge_blocks(
        dest_sections.get("Working Agreements", []),
        src_sections.get("Working Agreements", []),
    )
    merged["Top Rules"] = merge_blocks(
        dest_sections.get("Top Rules", []), src_sections.get("Top Rules", [])
    )
    merged["User Preferences"] = merge_blocks(
        dest_sections.get("User Preferences", []),
        src_sections.get("User Preferences", []),
    )

    dest_ids = parse_session_ids(dest_sections.get("Session Index", []))
    src_ids = parse_session_ids(src_sections.get("Session Index", []))
    merged_ids = list(dest_ids)
    for entry in src_ids:
        if entry not in merged_ids:
            merged_ids.append(entry)
    merged["Session Index"] = build_session_index(merged_ids)

    merged["Log"] = merge_logs(
        dest_sections.get("Log", []), src_sections.get("Log", [])
    )

    extras = merge_extras(dest_sections, dest_order, src_sections, src_order)
    merged_content = build_notebook(merged, extras)

    try:
        target_dir.mkdir(parents=True, exist_ok=True)
        tmp_path = target_path.with_suffix(".md.tmp")
        tmp_path.write_text(merged_content, encoding="utf-8")
        os.replace(tmp_path, target_path)
        if not target_path.exists() or target_path.stat().st_size == 0:
            raise RuntimeError("Migration failed, target notebook is empty.")
        source_path.unlink()
        print(f"Migrated notebook to {target_path}")
    except Exception as exc:
        print(f"Migration failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
