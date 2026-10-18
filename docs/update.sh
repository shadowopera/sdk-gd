#!/usr/bin/env bash

# Generates the GDScript pages of the docs site in ../docs/archmage: overview-gd from README.md and CHANGELOG.md,
# sdk-gd and gen-gd from the doc comments of addons/archmage and tests/conf, and gen-gd-editor from docs/gen-gd-editor.
# The image of README.md is the one of the C# SDK; ../sdk-cs/docs/update.sh copies it to the docs site.
#
# Set GODOT to the Godot executable to override /Applications/Godot_mono.app.

[[ "$TRACE" ]] && set -x
pushd "$(dirname "$0")" > /dev/null
trap __EXIT EXIT

colorful=false
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]]; then
    colorful=true
fi

function __EXIT() {
    [[ -n "${xml_tmp:-}" ]] && rm -rf "$xml_tmp"
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

# Move to project root
cd ..

siteDir=../docs/archmage/src/content/docs
if [[ ! -d "$siteDir" ]]; then
    printError "$siteDir does not exist"
    exit 1
fi
for f in README.md CHANGELOG.md; do
    if [[ ! -f "$f" ]]; then
        printError "$f does not exist"
        exit 1
    fi
done
editorPages=(docs/gen-gd-editor/*.mdx)
if [[ ! -f "${editorPages[0]}" ]]; then
    printError "docs/gen-gd-editor has no .mdx files"
    exit 1
fi

GODOT="${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/godot}"
if [[ ! -x "$GODOT" ]]; then
    printError "Godot not found at $GODOT. Set GODOT to the Godot executable."
    exit 1
fi

# Import, so that the class_name of the SDK is registered
printMessage "Importing resources ..."
if ! "$GODOT" --headless --path . --import > /dev/null 2>&1; then
    printError "Godot failed to import the project. Run: $GODOT --headless --path $PWD --import"
    exit 1
fi

xml_tmp="$(mktemp -d)"

function exportXml() {
    local res_dir="$1" out_dir="$2"
    printMessage "Exporting the doc comments of $res_dir ..."
    mkdir -p "$out_dir"
    if ! "$GODOT" --headless --path . --doctool "$out_dir" --gdscript-docs "$res_dir" > "$xml_tmp/doctool.log" 2>&1 \
        || ! ls "$out_dir"/*.xml > /dev/null 2>&1; then
        cat "$xml_tmp/doctool.log" >&2
        printError "godot --doctool failed for $res_dir"
        exit 1
    fi
}

exportXml res://addons/archmage "$xml_tmp/sdk"
exportXml res://tests/conf "$xml_tmp/conf"

printMessage "Cleaning the generated pages ..."
rm -rf "$siteDir/overview-gd" "$siteDir/sdk-gd" "$siteDir/gen-gd" "$siteDir/gen-gd-editor"
mkdir -p "$siteDir/overview-gd" "$siteDir/gen-gd-editor"

# Process README.md for Starlight
printMessage "Generating $siteDir/overview-gd/sdk-gd.mdx ..."
{
    echo "---"
    echo "title: 'GDScript SDK Overview'"
    echo "sidebar:"
    echo "  label: Overview"
    echo "  order: 1"
    echo "---"
    echo ""
    perl -0777 -pe 's/\n---\s+## Development.*//s' README.md | \
        perl -0777 -pe 's/^# GDScript SDK Overview\n\n//m' | \
        perl -pe 's|\./images/archmage\.jpg|../../../assets/archmage/archmage.jpg|g' | \
        perl -0777 -pe 's/^> \[!NOTE\]\n((?:> [^\n]*\n?)+)/my $b=$1; $b=~s{^> }{}gm; ":::note\n${b}:::\n"/gme'
} > "$siteDir/overview-gd/sdk-gd.mdx"

# Process CHANGELOG.md for Starlight
printMessage "Generating $siteDir/overview-gd/CHANGELOG.md ..."
{
    echo "---"
    echo "title: 'GDScript SDK Changelog'"
    echo "sidebar:"
    echo "  label: Changelog"
    echo "  order: 100"
    echo "---"
    echo ""
    tail -n +3 CHANGELOG.md
} > "$siteDir/overview-gd/CHANGELOG.md"

printMessage "Generating $siteDir/sdk-gd and $siteDir/gen-gd ..."
if ! node docs/gdscript-docs.mjs "$xml_tmp/sdk" "$xml_tmp/conf" "$siteDir"; then
    printError "gdscript-docs.mjs failed"
    exit 1
fi

printMessage "Copying $siteDir/gen-gd-editor ..."
cp "${editorPages[@]}" "$siteDir/gen-gd-editor/"

# Stage all changes
printMessage "Staging changes in docs site ..."
cd ../docs
git add -A

echo
printMessage "Done."
