#!/usr/bin/env bash

# Runs the tests in four modes, in this order: from the project directory, in an exported program (--exported),
# in a Web build without thread support, and in a Web build with thread support (--threads). It exits with 1 at the
# first mode that fails, so that the summary of that mode is at the end of the output.
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
if ! scripts/godot-test.sh --no-sync; then
    printError "Tests from the project directory failed."
    exit 1
fi

echo
printImportantMessage "Running tests in an exported program..."
if ! scripts/godot-test.sh --no-sync --exported; then
    printError "Tests in an exported program failed."
    exit 1
fi

echo
printImportantMessage "Running tests in a Web build without thread support..."
if ! scripts/godot-web-test.sh; then
    printError "Tests in a Web build without thread support failed."
    exit 1
fi

echo
printImportantMessage "Running tests in a Web build with thread support..."
if ! scripts/godot-web-test.sh --threads; then
    printError "Tests in a Web build with thread support failed."
    exit 1
fi

echo
printImportantMessage "All tests passed."
