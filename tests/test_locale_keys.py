#!/usr/bin/env python3
"""Verify that every translation has the same locale keys as English."""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
LOCALE_ROOT = REPO_ROOT / "locale"
SOURCE_LOCALE = "en"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--locale",
        action="append",
        help="Locale directory to check. Defaults to every locale except English.",
    )
    args, _unknown = parser.parse_known_args()
    return args


def parse_locale(path: Path) -> tuple[list[tuple[str, str]], list[str]]:
    entries: list[tuple[str, str]] = []
    errors: list[str] = []
    seen_sections: set[str] = set()
    seen_keys_by_section: dict[str, set[str]] = defaultdict(set)
    section: str | None = None

    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue

        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            if not section:
                errors.append(f"{path}:{line_number}: empty section name")
            elif section in seen_sections:
                errors.append(f"{path}:{line_number}: duplicate section [{section}]")
            seen_sections.add(section)
            entries.append((section, ""))
            continue

        if section is None:
            errors.append(f"{path}:{line_number}: key before first section")
            continue

        if "=" not in raw_line:
            errors.append(f"{path}:{line_number}: expected key=value entry")
            continue

        key = raw_line.split("=", 1)[0].strip()
        if not key:
            errors.append(f"{path}:{line_number}: empty key")
        elif key in seen_keys_by_section[section]:
            errors.append(f"{path}:{line_number}: duplicate key {section}.{key}")
        seen_keys_by_section[section].add(key)
        entries.append((section, key))

    return entries, errors


def locale_path(locale: str) -> Path:
    return LOCALE_ROOT / locale / "config.cfg"


def available_locales() -> list[str]:
    return sorted(
        path.name
        for path in LOCALE_ROOT.iterdir()
        if path.is_dir() and path.name != SOURCE_LOCALE and (path / "config.cfg").is_file()
    )


def compare_locale(source_entries: list[tuple[str, str]], target: str) -> list[str]:
    target_path = locale_path(target)
    target_entries, errors = parse_locale(target_path)
    source_set = set(source_entries)
    target_set = set(target_entries)

    for section, key in source_entries:
        if (section, key) not in target_set:
            label = f"[{section}]" if not key else f"{section}.{key}"
            errors.append(f"{target_path}: missing {label}")

    for section, key in target_entries:
        if (section, key) not in source_set:
            label = f"[{section}]" if not key else f"{section}.{key}"
            errors.append(f"{target_path}: extra {label}")

    if source_entries != target_entries and not errors:
        errors.append(f"{target_path}: keys match but ordering differs from English locale")

    return errors


def main() -> int:
    args = parse_args()
    source_path = locale_path(SOURCE_LOCALE)
    source_entries, source_errors = parse_locale(source_path)
    if source_errors:
        for error in source_errors:
            print(error, file=sys.stderr)
        return 1

    locales = args.locale or available_locales()
    if not locales:
        print("No translated locales found.")
        return 0

    errors: list[str] = []
    for locale in locales:
        path = locale_path(locale)
        if not path.is_file():
            errors.append(f"{path}: locale config not found")
            continue
        errors.extend(compare_locale(source_entries, locale))

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print(f"Locale keys match English for: {', '.join(locales)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
