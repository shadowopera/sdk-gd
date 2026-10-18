#!/usr/bin/env bash

# Generates addons/archmage/README.md from README.md, without the first two lines (the image) and without everything
# from "## Development" on. The Asset Store requires a README inside the addon directory.
#
# With --check, it generates nothing and fails when addons/archmage/README.md is not up to date.

[[ "$TRACE" ]] && set -x
pushd "$(dirname "$0")" > /dev/null
trap __EXIT EXIT

colorful=false
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]]; then
    colorful=true
fi

function __EXIT() {
    [[ -n "${tmp_file:-}" ]] && rm -f "$tmp_file"
    popd > /dev/null
}

function printMessage() {
    local timestamp=$([ -n "${WTS:-}" ] && [ "${WTS}" != "0" ] && date +'[%Y-%m-%d %H:%M:%S] ')
    >&2 echo "${timestamp}$*"
}

function printError() {
    $colorful && tput setaf 1 || true
    local timestamp=$([ -n "${WTS:-}" ] && [ "${WTS}" != "0" ] && date +'[%Y-%m-%d %H:%M:%S] ')
    >&2 echo "${timestamp}ERROR: $*"
    $colorful && tput sgr0 || true
}

check=false
if [[ "${1:-}" == "--check" ]]; then
    check=true
elif [[ -n "${1:-}" ]]; then
    printError "Usage: $0 [--check]"
    exit 1
fi

# Move to project root
cd ..

src_file=README.md
dst_file=addons/archmage/README.md

if [[ ! -f "$src_file" ]]; then
    printError "$src_file does not exist"
    exit 1
fi

tmp_file="$(mktemp)"
tail -n +3 "$src_file" | perl -0777 -pe 's/\n---\s+## Development.*//s' > "$tmp_file"

if cmp -s "$tmp_file" "$dst_file"; then
    printMessage "$dst_file is up to date."
elif $check; then
    printError "$dst_file is not up to date. Run scripts/sync-addon-readme.sh."
    exit 1
else
    cp "$tmp_file" "$dst_file"
    printMessage "Generated $dst_file."
fi
