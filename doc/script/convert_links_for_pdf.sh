#!/bin/bash

# Script to replace relative markdown links with GitHub links for PDF generation
# Preserves image links (they render in PDF) and external links

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <github-release-link> [input-file] [output-file]"
    echo ""
    echo "Example:"
    echo "  $0 https://github.com/CMTA/CMTAT/blob/v3.0.0"
    echo "  $0 https://github.com/CMTA/CMTAT/blob/v3.0.0 ../README.md README_UPDATE.md"
    exit 1
fi

GITHUB_LINK="${1%/}"  # Remove trailing slash if present

# Base URL for the *parent* of the input file's directory, used by Step 0.
# ".../blob/<ref>/doc" -> ".../blob/<ref>". The input file lives in doc/, so its
# links to repository-root siblings (test/, src/) are written "../path" and can
# only be rewritten against this. Empty when the base URL has no path segment
# after the ref: the input file is then the root README, and "../" from there
# points outside the repository.
GITHUB_LINK_PARENT=""
if [[ "$GITHUB_LINK" =~ ^(.*/blob/[^/]+)/(.+)$ ]]; then
    REF_BASE="${BASH_REMATCH[1]}"
    DIR_PATH="${BASH_REMATCH[2]}"
    if [ "$DIR_PATH" = "${DIR_PATH%/*}" ]; then
        GITHUB_LINK_PARENT="$REF_BASE"
    else
        GITHUB_LINK_PARENT="$REF_BASE/${DIR_PATH%/*}"
    fi
fi
INPUT_FILE="${2:-../README.md}"   # doc/README.md, the full reference (the root README is a short summary)
OUTPUT_FILE="${3:-README_UPDATE.md}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    exit 1
fi

# Create a temporary file
TMP_FILE=$(mktemp)
cp "$INPUT_FILE" "$TMP_FILE"

# Use a placeholder to avoid sed escaping issues
PLACEHOLDER="__GITHUB_LINK__"
PLACEHOLDER_PARENT="__GITHUB_LINK_PARENT__"

# Step 0: convert parent-relative links [text](../...) before Step 1, which only
# recognizes the "./" form and would leave these relative and dead in the PDF.
if grep -qE '\]\(\.\./[^)]+\)' "$TMP_FILE"; then
    if [ -z "$GITHUB_LINK_PARENT" ]; then
        echo "Error: '$INPUT_FILE' contains '../' links, but '$GITHUB_LINK' has no parent directory to resolve them against." >&2
        echo "Pass a base URL that includes the input file's own directory, e.g. https://github.com/CMTA/Rules/blob/<tag>/doc" >&2
        rm -f "$TMP_FILE"
        exit 1
    fi
    sed -i -E "s|\[([^]]+)\]\(\.\./([^)]+)\)|[\1]($PLACEHOLDER_PARENT/\2)|g" "$TMP_FILE"
fi

# Step 1: Convert ALL relative links [text](./...) to placeholder
sed -i -E "s|\[([^]]+)\]\(\./([^)]+)\)|[\1]($PLACEHOLDER/\2)|g" "$TMP_FILE"

# Step 2: Restore image links back to relative (images render inline in PDF)
for ext in png jpg jpeg gif svg ico webp bmp tiff; do
    sed -i -E "s|\[([^]]+)\]\($PLACEHOLDER/([^)]+\.$ext)\)|[\1](./\2)|gi" "$TMP_FILE"
    sed -i -E "s|\[([^]]+)\]\($PLACEHOLDER_PARENT/([^)]+\.$ext)\)|[\1](../\2)|gi" "$TMP_FILE"
done

# Step 3: Replace placeholders with actual GitHub links (parent first)
sed -i "s|$PLACEHOLDER_PARENT|$GITHUB_LINK_PARENT|g" "$TMP_FILE"
sed -i "s|$PLACEHOLDER|$GITHUB_LINK|g" "$TMP_FILE"

mv "$TMP_FILE" "$OUTPUT_FILE"

echo "Created '$OUTPUT_FILE' with GitHub links pointing to:"
echo "  $GITHUB_LINK"
