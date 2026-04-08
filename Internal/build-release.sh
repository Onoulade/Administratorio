#!/usr/bin/env sh

set -eu

usage() {
  cat <<'EOF'
Usage: Internal/build-release.sh [--no-tag] <version>

If <version> is newer than info.json, updates info.json, rolls CHANGELOG.md
forward for a release, regenerates Factorio changelog.txt, creates a release
commit, optionally adds an annotated tag, and builds a Factorio zip archive
next to the current mod folder.

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
CHANGELOG_MD="$REPO_ROOT/CHANGELOG.md"
CHANGELOG_TXT="$REPO_ROOT/changelog.txt"

[ -f "$INFO_JSON" ] || die "Missing info.json in $REPO_ROOT"
[ -f "$CHANGELOG_MD" ] || die "Missing CHANGELOG.md in $REPO_ROOT"
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
NOTES_FILE="$TMP_DIR/release-notes.md"
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

python3 - "$INFO_JSON" "$CHANGELOG_MD" "$CHANGELOG_TXT" "$NEW_VERSION" "$RELEASE_DATE" "$NOTES_FILE" "$RELEASE_MODE" <<'PY'
from pathlib import Path
import re
import sys

info_path = Path(sys.argv[1])
changelog_md_path = Path(sys.argv[2])
changelog_txt_path = Path(sys.argv[3])
new_version = sys.argv[4]
release_date = sys.argv[5]
notes_path = Path(sys.argv[6])
release_mode = sys.argv[7]


def extract_section(text, heading_pattern, missing_message):
    heading_match = re.search(heading_pattern, text, flags=re.MULTILINE)
    if heading_match is None:
        raise SystemExit(missing_message)

    remaining = text[heading_match.end():]
    next_section_match = re.search(r"^## .+$", remaining, flags=re.MULTILINE)
    notes = remaining[: next_section_match.start() if next_section_match else len(remaining)].strip("\n")

    if not notes.strip():
        raise SystemExit("The selected changelog section is empty")

    return notes, heading_match, next_section_match


def markdown_to_factorio(text):
    release_heading_pattern = re.compile(r"^## ([0-9]+\.[0-9]+\.[0-9]+) - (.+)$", flags=re.MULTILINE)
    category_heading_pattern = re.compile(r"^### (.+)$")
    bullet_pattern = re.compile(r"^\s*-\s+(.+)$")
    continuation_pattern = re.compile(r"^\s{2,}(.+)$")
    separator = "-" * 99
    category_map = {
        "Added": "Features",
        "Changed": "Changes",
        "Fixed": "Bugfixes",
        "Optimized": "Optimizations",
        "Performance": "Optimizations",
    }

    matches = list(release_heading_pattern.finditer(text))
    if not matches:
        raise SystemExit("Could not find any release sections in CHANGELOG.md")

    rendered_sections = []

    for idx, match in enumerate(matches):
        version = match.group(1).strip()
        date = match.group(2).strip()
        section_end = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
        section_body = text[match.end():section_end]

        category_order = []
        category_entries = {}
        current_category = None

        for raw_line in section_body.splitlines():
            line = raw_line.rstrip()

            if not line.strip():
                continue

            category_match = category_heading_pattern.match(line)
            if category_match:
                category_name = category_map.get(category_match.group(1).strip(), category_match.group(1).strip())
                current_category = category_name
                if category_name not in category_entries:
                    category_order.append(category_name)
                    category_entries[category_name] = []
                continue

            bullet_match = bullet_pattern.match(line)
            if bullet_match:
                if current_category is None:
                    raise SystemExit(
                        f"Found bullet entry before a category in CHANGELOG.md section {version}"
                    )
                category_entries[current_category].append([bullet_match.group(1).strip()])
                continue

            continuation_match = continuation_pattern.match(line)
            if continuation_match and current_category is not None and category_entries[current_category]:
                category_entries[current_category][-1].append(continuation_match.group(1).rstrip())
                continue

            if current_category is not None and category_entries[current_category]:
                category_entries[current_category][-1].append(line.strip())
                continue

            raise SystemExit(
                f"Unrecognized content in CHANGELOG.md section {version}: {line!r}"
            )

        lines = [
            separator,
            f"Version: {version}",
            f"Date: {date}",
        ]

        for category in category_order:
            entries = category_entries[category]
            seen_entries = set()
            deduped_entries = []
            for entry_lines in entries:
                key = "\n".join(entry_lines)
                if key in seen_entries:
                    continue
                seen_entries.add(key)
                deduped_entries.append(entry_lines)

            if not deduped_entries:
                continue

            lines.append(f"  {category}:")
            for entry_lines in deduped_entries:
                lines.append(f"    - {entry_lines[0]}")
                for continuation in entry_lines[1:]:
                    lines.append(f"      {continuation}")

        rendered_sections.append("\n".join(lines))

    return "\n\n".join(rendered_sections) + "\n"


info_text = info_path.read_text(encoding="utf-8")
changelog_md_text = changelog_md_path.read_text(encoding="utf-8")

if release_mode == "fresh":
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

    release_notes, unreleased_match, next_section_match = extract_section(
        changelog_md_text,
        r"^## Unreleased\s*$",
        "Could not find the ## Unreleased section in CHANGELOG.md",
    )

    unreleased_end = (
        unreleased_match.end() + next_section_match.start()
        if next_section_match
        else len(changelog_md_text)
    )

    updated_changelog = (
        changelog_md_text[:unreleased_match.start()]
        + "## Unreleased\n\n"
        + f"## {new_version} - {release_date}\n\n"
        + release_notes
    )

    if next_section_match:
        updated_changelog += "\n\n" + changelog_md_text[unreleased_end:].lstrip("\n")
    else:
        updated_changelog += "\n"

    info_path.write_text(info_text, encoding="utf-8")
    changelog_md_path.write_text(updated_changelog, encoding="utf-8")
    changelog_txt_path.write_text(markdown_to_factorio(updated_changelog), encoding="utf-8")
else:
    release_notes, _, _ = extract_section(
        changelog_md_text,
        rf"^## {re.escape(new_version)} - .+$",
        f"Could not find an existing ## {new_version} release section in CHANGELOG.md",
    )
    changelog_txt_path.write_text(markdown_to_factorio(changelog_md_text), encoding="utf-8")

notes_path.write_text(release_notes + "\n", encoding="utf-8")
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
