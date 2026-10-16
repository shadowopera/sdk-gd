#!/usr/bin/env bash

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

function printImportantMessage() {
    $colorful && tput setaf 3 || true
    local timestamp=$([ -n "${WTS:-}" ] && [ "${WTS}" != "0" ] && date +'[%Y-%m-%d %H:%M:%S] ')
    >&2 echo "${timestamp}$*"
    $colorful && tput sgr0 || true
}

# Move to project root
cd ..

# 1) Parse arguments
AUTO_YES=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes)
            AUTO_YES=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# 2) Get and clean version number
RAW_VERSION=${1:-}
if [[ -z "$RAW_VERSION" ]]; then
    printError "Missing version argument."
    echo "Usage: ./scripts/bump-version.sh [--yes] <version>"
    exit 1
fi

NEW_VERSION=$(echo "$RAW_VERSION" | sed 's/^[vV]//')

# 3) Validate semver with perl
if ! echo "$NEW_VERSION" | perl -ne 'exit 1 unless /^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/'; then
    printError "Invalid semver format: $NEW_VERSION"
    exit 1
fi

# 4) Confirm with gum (skip if --yes)
if ! $AUTO_YES; then
    if ! gum confirm "Bump version to $NEW_VERSION?"; then
        printMessage "Aborted."
        exit 0
    fi
fi

# 5) Update files
ARCHMAGE_GD="addons/archmage/archmage.gd"

printImportantMessage "Updating $ARCHMAGE_GD..."
sed -i '' "s/^const VERSION := \".*\"$/const VERSION := \"$NEW_VERSION\"/" "$ARCHMAGE_GD"

# Verify archmage.gd update
if ! grep -q "^const VERSION := \"$NEW_VERSION\"$" "$ARCHMAGE_GD"; then
    printError "Failed to update version in $ARCHMAGE_GD"
    exit 1
fi

# 6) Commit changes (skip if nothing to commit)
git add "$ARCHMAGE_GD"
if ! git diff --cached --quiet; then
    printImportantMessage "Committing changes..."
    git commit -m "chore: bump version to $NEW_VERSION"
    echo
    git show --stat HEAD
    echo
else
    printMessage "Version already up to date, skipping commit."
fi

printImportantMessage "Done."
