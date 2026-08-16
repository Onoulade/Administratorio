#!/usr/bin/env python3
"""Keep the Space Age automation pass localized in every shipped language.

The 0.6.2 release predates the automation pass and has unrelated translation
debt. This audit deliberately scopes itself to English config keys introduced
or changed after that release, so new tube, AI, waiver, courier, and cannon
content cannot silently fall back to English.
"""

from __future__ import annotations

import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
BASE_REVISION = "f96ddd1"
LANGUAGES = ("fr", "ru")


def parse_locale(text: str) -> dict[tuple[str, str], str]:
    section: str | None = None
    entries: dict[tuple[str, str], str] = {}

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section and "=" in raw_line:
            key, value = raw_line.split("=", 1)
            entries[(section, key)] = value

    return entries


def load_language(language: str) -> dict[tuple[str, str], str]:
    entries: dict[tuple[str, str], str] = {}
    for locale_file in sorted((REPO_ROOT / "locale" / language).glob("*.cfg")):
        entries.update(parse_locale(locale_file.read_text(encoding="utf-8")))
    return entries


def base_english_config() -> dict[tuple[str, str], str]:
    result = subprocess.run(
        ["git", "show", f"{BASE_REVISION}:locale/en/config.cfg"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return parse_locale(result.stdout)


def main() -> None:
    baseline = base_english_config()
    english = parse_locale((REPO_ROOT / "locale" / "en" / "config.cfg").read_text(encoding="utf-8"))
    automation_keys = {
        pair
        for pair, value in english.items()
        if baseline.get(pair) != value
    }
    assert automation_keys, "expected Space Age automation locale changes after 0.6.2"

    for language in LANGUAGES:
        localized = load_language(language)
        missing = sorted(pair for pair in automation_keys if pair not in localized)
        assert not missing, (
            f"{language} is missing localization for Space Age automation content: "
            + ", ".join(f"{section}.{key}" for section, key in missing)
        )

    print(
        "Space Age automation localization coverage passed "
        f"({len(automation_keys)} English keys × {len(LANGUAGES)} languages)"
    )


if __name__ == "__main__":
    main()
