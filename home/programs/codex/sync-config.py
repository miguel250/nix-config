#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import tempfile
import tomllib
from pathlib import Path


def read_config(path: Path) -> dict[str, object]:
    with path.open("rb") as source:
        return tomllib.load(source)


def project_configs(config: dict[str, object]) -> dict[str, dict[str, object]]:
    projects = config.get("projects", {})
    if not isinstance(projects, dict) or any(
        not isinstance(project, dict) for project in projects.values()
    ):
        raise ValueError("Codex projects must be a table of project tables")
    return projects


def write_config(destination: Path, contents: bytes) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = tempfile.NamedTemporaryFile(
        mode="wb", prefix=".config.toml.", dir=destination.parent, delete=False
    )
    temporary_path = Path(temporary.name)
    try:
        with temporary:
            temporary.write(contents)
            os.fchmod(temporary.fileno(), 0o644)
        temporary_path.replace(destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def sync_config(generated: Path, destination: Path) -> None:
    contents = generated.read_text(encoding="utf-8").rstrip() + "\n"
    declared_projects = project_configs(tomllib.loads(contents))
    try:
        previous = read_config(destination)
    except FileNotFoundError:
        previous = {}

    for path, project in sorted(project_configs(previous).items()):
        if path in declared_projects:
            continue
        trust_level = project.get("trust_level")
        if trust_level is None:
            continue
        if trust_level not in ("trusted", "untrusted"):
            raise ValueError(f"Invalid Codex trust level for {path!r}")

        # TOML basic strings also require escaping DEL, unlike JSON strings.
        quoted_path = json.dumps(path, ensure_ascii=False).replace("\x7f", "\\u007f")
        contents += f'\n[projects.{quoted_path}]\ntrust_level = "{trust_level}"\n'

    tomllib.loads(contents)
    write_config(destination, contents.encode("utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("generated", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    try:
        sync_config(args.generated, args.destination)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Unable to sync Codex configuration: {error}\n")


if __name__ == "__main__":
    main()
