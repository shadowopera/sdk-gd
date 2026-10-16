#!/usr/bin/env bash

# Exports the tests for Web and runs them in headless Chrome.
#
# Usage: scripts/godot-web-test.sh [--threads]
#   --threads  export the "Web threads (tests)" preset, a build with thread support; without it, the
#              "Web (tests)" preset is exported, a build without thread support, which is the default of Godot
#
# The .NET editor cannot export for Web, so the export uses the standard editor and its export templates.
# The log and a summary go to logs/godot-<mode>.log and godot-<mode>-summary.txt (mode: web or web-threads).
# The exit code is 0 when all tests pass, 1 when a test fails, and 2 on a timeout.
#
# Set GODOT_STANDARD to the standard Godot executable to override /Applications/Godot.app,
# and CHROME to the Chrome executable.

[[ "$TRACE" ]] && set -x
cd "$(dirname "$0")/.."

function printError() {
    >&2 echo "ERROR: $*"
}

threads=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --threads)
            threads=true
            shift
            ;;
        *)
            printError "Unknown argument: $1"
            echo "Usage: ./scripts/godot-web-test.sh [--threads]"
            exit 1
            ;;
    esac
done

mode=web
preset="Web (tests)"
if $threads; then
    mode=web-threads
    preset="Web threads (tests)"
fi

PROJECT_DIR="$(pwd)"
LOG_DIR="$PROJECT_DIR/logs"
BUILD_DIR="$PROJECT_DIR/builds/$mode"
LOG_FILE="$LOG_DIR/godot-$mode.log"
SUMMARY_FILE="$LOG_DIR/godot-$mode-summary.txt"
EXPORT_LOG_FILE="$LOG_DIR/godot-$mode-export.log"

GODOT_STANDARD="${GODOT_STANDARD:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_STANDARD" ]]; then
    printError "Godot not found at $GODOT_STANDARD. Set GODOT_STANDARD to a standard (non-.NET) Godot executable."
    exit 1
fi
godot_version="$("$GODOT_STANDARD" --version | sed -E 's/\.[^.]+\.[^.]+$//')"
templates_dir="$HOME/Library/Application Support/Godot/export_templates/$godot_version"
if [[ ! -f "$templates_dir/web_nothreads_release.zip" ]]; then
    printError "Web export templates $godot_version not found in $templates_dir."
    exit 1
fi

mkdir -p "$LOG_DIR"
rm -f "$SUMMARY_FILE"

echo "Importing resources..."
if ! "$GODOT_STANDARD" --headless --path "$PROJECT_DIR" --import > /dev/null 2>&1; then
    printError "Godot failed to import the project."
    exit 1
fi

# Godot may exit with 0 even when the export fails, so the log is checked too.
echo "Exporting the $preset preset (log: $EXPORT_LOG_FILE)..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
if ! "$GODOT_STANDARD" --headless --path "$PROJECT_DIR" --export-release "$preset" "$BUILD_DIR/index.html" \
        > "$EXPORT_LOG_FILE" 2>&1 || grep -q "ERROR" "$EXPORT_LOG_FILE" || [[ ! -f "$BUILD_DIR/index.wasm" ]]; then
    printError "Export failed. See $EXPORT_LOG_FILE."
    exit 1
fi

echo "Running tests in headless Chrome (log: $LOG_FILE)..."
node scripts/godot-web-test.mjs "$BUILD_DIR" 300 > "$LOG_FILE" 2>&1
status=$?
# The summary of the test runner: the failures, then the totals.
sed -n '/^FAILED /,$p;/^Total: /p' "$LOG_FILE" | awk '!seen[$0]++' > "$SUMMARY_FILE"
cat "$SUMMARY_FILE"
[[ $status -eq 2 ]] && printError "Timed out. See $LOG_FILE."
echo "Summary: $SUMMARY_FILE"
exit $status
