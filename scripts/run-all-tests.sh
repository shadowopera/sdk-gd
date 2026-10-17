#!/usr/bin/env bash

# Runs the tests in four modes: from the project directory, in an exported program (--exported), in a Web build
# without thread support, and in a Web build with thread support (--threads). A mode that fails does not stop the
# later modes; the exit code is 0 only when all modes pass.
#
# Usage: scripts/run-all-tests.sh [--no-sync]
#   --no-sync  skip scripts/sync-testdata.sh
#
# Needs what scripts/godot-test.sh and scripts/godot-web-test.sh need.

[[ "$TRACE" ]] && set -x
pushd "$(dirname "$0")" > /dev/null
trap __EXIT EXIT

colorful=false
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]]; then
    colorful=true
fi

function __EXIT() {
    popd > /dev/null
}

function printError() {
    $colorful && tput setaf 1 || true
    local timestamp=$([ -n "${WTS:-}" ] && [ "${WTS}" != "0" ] && date +'[%Y-%m-%d %H:%M:%S] ')
    >&2 echo "${timestamp}ERROR: $*"
    $colorful && tput sgr0 || true
}

function printImportantMessage() {
    $colorful && tput setaf 3 || true
    local timestamp=$([ -n "${WTS:-}" ] && [ "${WTS}" != "0" ] && date +'[%Y-%m-%d %H:%M:%S] ')
    >&2 echo "${timestamp}$*"
    $colorful && tput sgr0 || true
}

# Move to project root
cd ..

sync=true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-sync)
            sync=false
            shift
            ;;
        *)
            printError "Unknown argument: $1"
            echo "Usage: ./scripts/run-all-tests.sh [--no-sync]"
            exit 1
            ;;
    esac
done

if $sync; then
    if ! scripts/sync-testdata.sh; then
        printError "sync-testdata.sh failed."
        exit 1
    fi
fi

echo
printImportantMessage "Running tests from the project directory..."
path_ok=true
scripts/godot-test.sh --no-sync || path_ok=false

echo
printImportantMessage "Running tests in an exported program..."
exported_ok=true
scripts/godot-test.sh --no-sync --exported || exported_ok=false

echo
printImportantMessage "Running tests in a Web build without thread support..."
web_ok=true
scripts/godot-web-test.sh || web_ok=false

echo
printImportantMessage "Running tests in a Web build with thread support..."
web_threads_ok=true
scripts/godot-web-test.sh --threads || web_threads_ok=false

if ! $path_ok; then
    echo
    printError "Tests from the project directory failed."
fi
if ! $exported_ok; then
    echo
    printError "Tests in an exported program failed."
fi
if ! $web_ok; then
    echo
    printError "Tests in a Web build without thread support failed."
fi
if ! $web_threads_ok; then
    echo
    printError "Tests in a Web build with thread support failed."
fi
if ! $path_ok || ! $exported_ok || ! $web_ok || ! $web_threads_ok; then
    exit 1
fi

echo
printImportantMessage "All tests passed."
