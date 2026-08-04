#!/usr/bin/env python3
"""Dependency-free validator for the TG Agent Plugin source payload."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PLACEHOLDER = re.compile(r"\b(?:TODO|TBD|FIXME)\b|\[TODO:", re.IGNORECASE)
NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def fail(message: str) -> None:
    raise ValueError(message)


def frontmatter(skill: Path) -> dict[str, str]:
    content = skill.read_text(encoding="utf-8")
    if PLACEHOLDER.search(content):
        fail(f"placeholder found in {skill}")
    match = re.match(r"^---\n(.*?)\n---\n", content, re.DOTALL)
    if not match:
        fail(f"missing frontmatter in {skill}")
    values: dict[str, str] = {}
    for line in match.group(1).splitlines():
        key, separator, value = line.partition(":")
        if not separator:
            fail(f"invalid frontmatter line in {skill}: {line}")
        values[key] = value.strip()
    if set(values) != {"name", "description"}:
        fail(f"frontmatter must contain only name and description in {skill}")
    if skill.parent.name != values["name"] or not NAME.fullmatch(values["name"]):
        fail(f"skill name does not match its directory in {skill}")
    if not values["description"]:
        fail(f"empty skill description in {skill}")
    return values


def validate(plugin: Path) -> None:
    manifest_path = plugin / ".codex-plugin" / "plugin.json"
    if not manifest_path.is_file():
        fail("missing .codex-plugin/plugin.json")
    raw_manifest = manifest_path.read_text(encoding="utf-8")
    if PLACEHOLDER.search(raw_manifest):
        fail("placeholder found in plugin manifest")
    manifest = json.loads(raw_manifest)
    if manifest.get("name") != plugin.name or not NAME.fullmatch(plugin.name):
        fail("plugin name must match its directory")
    if not SEMVER.fullmatch(str(manifest.get("version", ""))):
        fail("plugin version must use strict semver")
    for field in ("description", "author", "interface"):
        if not manifest.get(field):
            fail(f"missing manifest field: {field}")
    if not manifest["author"].get("name"):
        fail("missing author.name")
    for field in (
        "displayName",
        "shortDescription",
        "longDescription",
        "developerName",
        "category",
        "capabilities",
    ):
        if field not in manifest["interface"]:
            fail(f"missing interface field: {field}")
    prompts = manifest["interface"].get("defaultPrompt", [])
    if isinstance(prompts, list) and len(prompts) > 3:
        fail("defaultPrompt contains more than three entries")
    for field in ("composerIcon", "logo", "logoDark"):
        value = manifest["interface"].get(field)
        if value and not (plugin / value).is_file():
            fail(f"missing manifest asset: {value}")
    skills = sorted((plugin / "skills").glob("*/SKILL.md"))
    if not skills:
        fail("plugin contains no skills")
    for skill in skills:
        frontmatter(skill)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_plugin.py <plugin-path>", file=sys.stderr)
        return 2
    try:
        validate(Path(sys.argv[1]).resolve())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Plugin validation failed: {error}", file=sys.stderr)
        return 1
    print(f"Plugin validation passed: {Path(sys.argv[1]).resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
