#!/usr/bin/env sh

set -eu

usage() {
  cat <<'EOF'
Usage: Internal/build-release.sh [--no-tag] <version>

Stamps the Unreleased section in changelog.txt with <version> and today's
date, bumps info.json, creates a release commit and annotated tag, then
builds a Factorio zip archive next to the current mod folder.

If <version> matches info.json, rebuilds the archive for that release without
changing version metadata or creating a new release commit.

Examples:
  Internal/build-release.sh 0.1.2
  Internal/build-release.sh --no-tag 0.1.2
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

CREATE_TAG=1
NEW_VERSION=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-tag)
      CREATE_TAG=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      if [ -n "$NEW_VERSION" ]; then
        die "Only one version argument is supported"
      fi
      NEW_VERSION="$1"
      shift
      ;;
  esac
done

if [ -z "$NEW_VERSION" ]; then
  usage
  exit 1
fi

printf '%s\n' "$NEW_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || die "Version must look like x.y.z"

require_command git
require_command python3

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
INFO_JSON="$REPO_ROOT/info.json"
CHANGELOG_TXT="$REPO_ROOT/changelog.txt"

[ -f "$INFO_JSON" ] || die "Missing info.json in $REPO_ROOT"
[ -f "$CHANGELOG_TXT" ] || die "Missing changelog.txt in $REPO_ROOT"
git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$REPO_ROOT is not a git repository"

mod_info="$(
  python3 - "$INFO_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    info = json.load(fh)

print(info["name"])
print(info["version"])
PY
)"

MOD_NAME="$(printf '%s\n' "$mod_info" | sed -n '1p')"
CURRENT_VERSION="$(printf '%s\n' "$mod_info" | sed -n '2p')"

TAG_NAME="v$NEW_VERSION"
TAG_EXISTS=0
RELEASE_MODE="fresh"

if git -C "$REPO_ROOT" rev-parse --verify --quiet "refs/tags/$TAG_NAME" >/dev/null; then
  TAG_EXISTS=1
fi

if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
  RELEASE_MODE="rerelease"
fi

if [ "$RELEASE_MODE" = "fresh" ] && [ "$CREATE_TAG" -eq 1 ]; then
  if [ "$TAG_EXISTS" -eq 1 ]; then
    die "Tag $TAG_NAME already exists"
  fi
fi

RELEASE_DATE="$(date +%F)"
TMP_DIR="$(mktemp -d)"
NOTES_FILE="$TMP_DIR/release-notes.txt"
COMMIT_MSG_FILE="$TMP_DIR/commit-message.txt"
PATHS_FILE="$TMP_DIR/release-paths.bin"
ARCHIVE_PATH="$(cd -- "$REPO_ROOT/.." && pwd)/${MOD_NAME}_${NEW_VERSION}.zip"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup 0

if [ "$RELEASE_MODE" = "fresh" ]; then
  [ ! -e "$ARCHIVE_PATH" ] || die "Archive already exists: $ARCHIVE_PATH"
else
  rm -f "$ARCHIVE_PATH"
fi

python3 - "$INFO_JSON" "$CHANGELOG_TXT" "$NEW_VERSION" "$RELEASE_DATE" "$NOTES_FILE" "$RELEASE_MODE" <<'PY'
from pathlib import Path
import re
import sys

info_path = Path(sys.argv[1])
changelog_path = Path(sys.argv[2])
new_version = sys.argv[3]
release_date = sys.argv[4]
notes_path = Path(sys.argv[5])
release_mode = sys.argv[6]

info_text = info_path.read_text(encoding="utf-8")
changelog_text = changelog_path.read_text(encoding="utf-8")

separator = "-" * 99

if release_mode == "fresh":
    # Bump info.json version
    version_match = re.search(r'^(\s*"version"\s*:\s*")([^"]+)(")', info_text, flags=re.MULTILINE)
    if version_match is None:
        raise SystemExit("Could not find the version field in info.json")

    current_version = version_match.group(2)
    if current_version == new_version:
        raise SystemExit(f"info.json is already at version {new_version}")

    info_text = (
        info_text[:version_match.start()]
        + f'{version_match.group(1)}{new_version}{version_match.group(3)}'
        + info_text[version_match.end():]
    )
    info_path.write_text(info_text, encoding="utf-8")

    # Stamp the Unreleased section in changelog.txt
    unreleased_pattern = re.compile(
        r"^(Version:\s*)Unreleased\s*$",
        flags=re.MULTILINE,
    )
    unreleased_match = unreleased_pattern.search(changelog_text)
    if unreleased_match is None:
        raise SystemExit("Could not find a 'Version: Unreleased' section in changelog.txt")

    # Replace "Version: Unreleased" with versioned header and insert Date line
    replacement = f"Version: {new_version}\nDate: {release_date}"
    changelog_text = (
        changelog_text[:unreleased_match.start()]
        + replacement
        + changelog_text[unreleased_match.end():]
    )
    changelog_path.write_text(changelog_text, encoding="utf-8")

    # Extract release notes for the commit message
    section_start = unreleased_match.start()
    next_separator = changelog_text.find(separator, section_start + len(separator))
    if next_separator == -1:
        section_body = changelog_text[section_start:]
    else:
        section_body = changelog_text[section_start:next_separator]

    # Collect bullet points from the section
    notes_lines = []
    for line in section_body.splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            notes_lines.append(stripped)
        elif stripped and not stripped.startswith("Version:") and not stripped.startswith("Date:") and ":" in stripped:
            notes_lines.append("")
            notes_lines.append(stripped)

    notes_path.write_text("\n".join(notes_lines).strip() + "\n", encoding="utf-8")

else:
    # Rerelease: just extract notes for the tag
    version_pattern = re.compile(
        rf"^Version:\s*{re.escape(new_version)}\s*$",
        flags=re.MULTILINE,
    )
    version_match = version_pattern.search(changelog_text)
    if version_match is None:
        raise SystemExit(f"Could not find Version: {new_version} in changelog.txt")

    section_start = version_match.start()
    next_separator = changelog_text.find(separator, section_start + len(separator))
    if next_separator == -1:
        section_body = changelog_text[section_start:]
    else:
        section_body = changelog_text[section_start:next_separator]

    notes_lines = []
    for line in section_body.splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            notes_lines.append(stripped)

    notes_path.write_text("\n".join(notes_lines).strip() + "\n", encoding="utf-8")
PY

{
  printf 'Release %s\n\n' "$NEW_VERSION"
  cat "$NOTES_FILE"
} > "$COMMIT_MSG_FILE"

python3 - "$REPO_ROOT" <<'PY' > "$PATHS_FILE"
from pathlib import Path, PurePosixPath
import subprocess
import sys

repo_root = Path(sys.argv[1])

def git_paths(*args):
    data = subprocess.check_output(
        ["git", "-C", str(repo_root), "ls-files", *args, "-z"],
        text=False,
    )
    return [item for item in data.decode("utf-8").split("\0") if item]

for path in sorted(set(git_paths() + git_paths("--others", "--exclude-standard"))):
    parts = PurePosixPath(path).parts
    if any(part.startswith(".") for part in parts[:-1]):
        continue
    sys.stdout.write(path)
    sys.stdout.write("\0")
PY

[ -s "$PATHS_FILE" ] || die "No releasable paths were found"

if [ "$RELEASE_MODE" = "fresh" ]; then
  xargs -0 git -C "$REPO_ROOT" add -A -- < "$PATHS_FILE"
  git -C "$REPO_ROOT" commit --file "$COMMIT_MSG_FILE"
fi

python3 - "$REPO_ROOT" "$ARCHIVE_PATH" "$MOD_NAME" "$NEW_VERSION" <<'PY'
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
import sys

repo_root = Path(sys.argv[1]).resolve()
archive_path = Path(sys.argv[2]).resolve()
mod_name = sys.argv[3]
version = sys.argv[4]
archive_root = f"{mod_name}_{version}"

with ZipFile(archive_path, "w", compression=ZIP_DEFLATED) as zf:
    for path in sorted(repo_root.rglob("*")):
        if path.is_dir():
            continue

        rel_path = path.relative_to(repo_root)
        parts = rel_path.parts

        if any(part.startswith(".") for part in parts):
            continue
        if "Internal" in parts:
            continue
        if "tests" in parts:
            continue

        zf.write(path, arcname=str(Path(archive_root, rel_path)))
PY

if [ "$CREATE_TAG" -eq 1 ] && [ "$TAG_EXISTS" -eq 0 ]; then
  git -C "$REPO_ROOT" tag -a "$TAG_NAME" -F "$COMMIT_MSG_FILE"
fi

printf 'Released %s -> %s\n' "$NEW_VERSION" "$ARCHIVE_PATH"
if [ "$CREATE_TAG" -eq 1 ]; then
  if [ "$TAG_EXISTS" -eq 1 ]; then
    printf 'Reused tag %s\n' "$TAG_NAME"
  else
    printf 'Created tag %s\n' "$TAG_NAME"
  fi
fi
