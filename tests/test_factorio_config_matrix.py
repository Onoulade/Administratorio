#!/usr/bin/env python3
"""Load the mod through Factorio under its supported startup configurations."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", help="Path to the Factorio executable.")
    return parser.parse_args()


def mod_name() -> str:
    return json.loads((REPO_ROOT / "info.json").read_text())["name"]


def write_profile(root: Path, *, space_age: bool, working_hours: bool) -> Path:
    mods_dir = root / "mods"
    mods_dir.mkdir(parents=True)
    target = mods_dir / mod_name()

    if working_hours:
        target.symlink_to(REPO_ROOT, target_is_directory=True)
    else:
        shutil.copytree(
            REPO_ROOT,
            target,
            ignore=shutil.ignore_patterns(".git", ".agents", "__pycache__"),
        )
        settings_path = target / "settings.lua"
        settings = settings_path.read_text()
        original = 'name = "administratorio-enable-working-hours",\n    setting_type = "startup",\n    default_value = true,'
        replacement = 'name = "administratorio-enable-working-hours",\n    setting_type = "startup",\n    default_value = false,'
        assert original in settings, "could not locate the Working Hours startup default"
        settings_path.write_text(settings.replace(original, replacement, 1))

    # Built-in expansion mods default to enabled when omitted. Declare their
    # disabled state too, otherwise the base-only case accidentally loads
    # Space Age and validates nothing.
    enabled = {
        "base": True,
        "elevated-rails": space_age,
        "quality": space_age,
        "space-age": space_age,
        mod_name(): True,
    }
    (mods_dir / "mod-list.json").write_text(
        json.dumps(
            {"mods": [{"name": name, "enabled": is_enabled} for name, is_enabled in enabled.items()]},
            indent=2,
        )
        + "\n"
    )
    (root / "config.ini").write_text(
        "[path]\n"
        "read-data=__PATH__system-read-data__\n"
        f"write-data={root}\n\n"
        "[general]\n"
        "locale=auto\n"
    )
    return root


def dump_data(factorio_bin: Path, root: Path) -> dict:
    command = [
        str(factorio_bin),
        "--config",
        str(root / "config.ini"),
        "--mod-directory",
        str(root / "mods"),
        "--disable-audio",
        "--dump-data",
    ]
    result = subprocess.run(command, cwd=REPO_ROOT, text=True, capture_output=True)
    if result.returncode:
        raise AssertionError(
            "Factorio failed to load this startup configuration:\n"
            + result.stdout
            + result.stderr
        )
    return json.loads((root / "script-output" / "data-raw-dump.json").read_text())


def run_case(factorio_bin: Path, *, space_age: bool, working_hours: bool) -> dict:
    with tempfile.TemporaryDirectory(prefix="administratorio-config-matrix-") as temp:
        root = write_profile(Path(temp), space_age=space_age, working_hours=working_hours)
        return dump_data(factorio_bin, root)


def main() -> None:
    args = parse_args()
    if not args.factorio_bin:
        print("Skipping Factorio startup configuration matrix; --factorio-bin was not provided.")
        return

    factorio_bin = Path(args.factorio_bin)
    if not factorio_bin.exists():
        raise FileNotFoundError(f"Factorio binary not found: {factorio_bin}")

    base = run_case(factorio_bin, space_age=False, working_hours=True)
    assert "optical-fibre" not in base.get("item", {}), "base-only load must not expose a missing fibre entity"
    assert "inference-token" not in base.get("fluid", {}), "base-only load must not expose orphan AI fluid"
    assert "unstaffed-operations-waiver" not in base.get("module", {}), (
        "base-only load must not expose the Space Age-only waiver module"
    )

    no_working_hours = run_case(factorio_bin, space_age=True, working_hours=False)
    assert "unstaffed-operations" not in no_working_hours.get("technology", {}), (
        "disabled Working Hours must not expose a technology whose recipe does not exist"
    )
    assert "unstaffed-operations-waiver" not in no_working_hours.get("module", {}), (
        "disabled Working Hours must not register its waiver module"
    )

    print("Factorio startup configuration matrix passed")


if __name__ == "__main__":
    main()
