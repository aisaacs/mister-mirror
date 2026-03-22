#!/bin/bash
# Creates a new release by bumping the version tag and pushing to GitHub.
# Usage:
#   ./scripts/release.sh          # bumps patch (v1.0 -> v1.1)
#   ./scripts/release.sh 2.0      # sets specific version (v2.0)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

# Get the latest tag
LATEST_TAG=$(git tag --sort=-v:refname | head -n1 2>/dev/null || echo "")

if [ -n "$1" ]; then
    NEW_VERSION="$1"
else
    if [ -z "$LATEST_TAG" ]; then
        NEW_VERSION="1.0"
    else
        # Strip 'v' prefix, bump minor version
        CURRENT="${LATEST_TAG#v}"
        MAJOR="${CURRENT%%.*}"
        MINOR="${CURRENT#*.}"
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION="${MAJOR}.${NEW_MINOR}"
    fi
fi

NEW_TAG="v${NEW_VERSION}"

echo "Current tag: ${LATEST_TAG:-none}"
echo "New tag:     $NEW_TAG"
echo ""

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "You have uncommitted changes:"
    git status --short
    echo ""
    read -p "Commit them with message 'Release $NEW_TAG'? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add -A
        git commit -m "Release $NEW_TAG"
    else
        echo "Aborting. Commit your changes first."
        exit 1
    fi
fi

# Update version in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_VERSION" Info.plist

# Commit version bump if it changed anything
if ! git diff --quiet Info.plist; then
    git add Info.plist
    git commit -m "Bump version to $NEW_VERSION"
fi

# Push commits
git push

# Create and push tag
git tag "$NEW_TAG"
git push origin "$NEW_TAG"

echo ""
echo "==> Released $NEW_TAG"
echo "    GitHub Actions will build the DMG and create the release."
echo "    Watch it: https://github.com/aisaacs/mister-mirror/actions"
