#!/usr/bin/env python3
"""Require every shipped translation to cover the English locale surface."""

from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ("en", "fr", "ru")
PLACEHOLDER_RE = re.compile(r"__\d+__")


def load_locale(language: str) -> dict[tuple[str, str], str]:
    entries: dict[tuple[str, str], str] = {}
    for path in sorted((REPO_ROOT / "locale" / language).glob("*.cfg")):
        section: str | None = None
        for line_number, raw_line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            line = raw_line.strip()
            if not line or line.startswith(("#", ";")):
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1]
                continue
            if "=" not in raw_line or section is None:
                continue
            key, value = raw_line.split("=", 1)
            pair = (section, key.strip())
            if pair in entries:
                raise AssertionError(
                    f"duplicate locale key {section}.{key.strip()} in {path}:{line_number}"
                )
            entries[pair] = value
    return entries


def main() -> None:
    locales = {language: load_locale(language) for language in LANGUAGES}
    english = locales["en"]
    failures: list[str] = []

    for language in LANGUAGES[1:]:
        translated = locales[language]
        missing = sorted(set(english) - set(translated))
        if missing:
            failures.append(
                f"{language} missing: "
                + ", ".join(f"{section}.{key}" for section, key in missing)
            )

        for pair in sorted(set(english) & set(translated)):
            expected = set(PLACEHOLDER_RE.findall(english[pair]))
            actual = set(PLACEHOLDER_RE.findall(translated[pair]))
            if actual != expected:
                failures.append(
                    f"{language} placeholder mismatch for {pair[0]}.{pair[1]}: "
                    f"expected {sorted(expected)}, got {sorted(actual)}"
                )

    assert not failures, "\n" + "\n".join(failures)
    print(
        "Locale parity passed: "
        f"{len(english)} English keys covered in {', '.join(LANGUAGES[1:])}"
    )


if __name__ == "__main__":
    main()
