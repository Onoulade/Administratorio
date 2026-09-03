#!/bin/sh

set -eu
export PYTHONDONTWRITEBYTECODE=1

usage() {
  cat <<'EOF'
Usage: ./run-tests.sh --repo-root PATH [--factorio-bin PATH] [-- PYTHON_TEST_ARGS...]

Required arguments:
  --repo-root PATH     Absolute or relative path to the repo root.

Optional arguments:
  --factorio-bin PATH  Factorio binary passed to the runtime and configuration tests.
  --help               Show this help text.

Any arguments after -- are forwarded to Python tests.
If --factorio-bin is omitted, tests/test_progression_report.py is skipped.
EOF
}

REPO_ROOT=
FACTORIO_BIN=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-root)
      [ "$#" -ge 2 ] || { echo "Missing value for --repo-root" >&2; exit 1; }
      REPO_ROOT=$2
      shift 2
      ;;
    --factorio-bin)
      [ "$#" -ge 2 ] || { echo "Missing value for --factorio-bin" >&2; exit 1; }
      FACTORIO_BIN=$2
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[ -n "$REPO_ROOT" ] || { echo "--repo-root is required" >&2; exit 1; }
command -v lua >/dev/null 2>&1 || { echo "'lua' not found on PATH" >&2; exit 1; }
command -v luac >/dev/null 2>&1 || { echo "'luac' not found on PATH" >&2; exit 1; }

# Prefer python3. Fall back to python only if it is Python 3.
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=python
else
  echo "Neither 'python3' nor 'python' found on PATH" >&2
  exit 1
fi

"$PYTHON_BIN" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1 || {
  echo "'$PYTHON_BIN' must be Python 3 for tests/test_progression_report.py" >&2
  exit 1
}

TEST_DIR=$REPO_ROOT/tests

if [ ! -d "$TEST_DIR" ]; then
  echo "Test directory not found: $TEST_DIR" >&2
  exit 1
fi

run_lua_tests() {
  for test_file in "$TEST_DIR"/test_*.lua; do
    [ -f "$test_file" ] || continue
    printf '==> %s\n' "$(basename "$test_file")"
    lua "$test_file"
  done
}

run_lua_syntax_checks() {
  printf '==> Lua syntax check\n'
  find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -type f -name '*.lua' -print |
  while IFS= read -r lua_file; do
    [ -n "$lua_file" ] || continue
    luac -p "$lua_file"
  done
}

run_python_tests() {
  for test_file in "$TEST_DIR"/test_*.py; do
    [ -f "$test_file" ] || continue
    printf '==> %s\n' "$(basename "$test_file")"
    test_name=$(basename "$test_file")
    if [ "$test_name" = "test_progression_report.py" ] || [ "$test_name" = "test_planet_escape.py" ] || [ "$test_name" = "test_factorio_config_matrix.py" ] || [ "$test_name" = "test_factorio_runtime_smoke.py" ]; then
      if [ -z "$FACTORIO_BIN" ]; then
        printf 'Skipping %s; --factorio-bin was not provided.\n' "$test_name"
        continue
      fi
      if [ "$test_name" = "test_planet_escape.py" ]; then
        "$PYTHON_BIN" "$test_file" --factorio-bin "$FACTORIO_BIN" --enforce-import-policy "$@"
      else
        "$PYTHON_BIN" "$test_file" --factorio-bin "$FACTORIO_BIN" "$@"
      fi
    else
      "$PYTHON_BIN" "$test_file" "$@"
    fi
  done
}

cd "$REPO_ROOT"
run_lua_syntax_checks
run_lua_tests
run_python_tests "$@"

echo "All tests passed."
