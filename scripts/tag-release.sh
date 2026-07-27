#!/usr/bin/env bash
# Verify and publish the release that is already committed on the current
# branch: reads the version from pubspec.yaml, checks the tree is clean and
# analyze + tests are green, then pushes the branch and the matching
# `v<version>` tag (which is what triggers .github/workflows/release.yml).
#
# The commit itself is deliberately NOT automated — the message is the part
# that needs a human. Commit first, then run this.
#
# DRY RUN by default; pass --go to push.
#
# Usage:
#   bash scripts/tag-release.sh              # verify + show what would happen
#   bash scripts/tag-release.sh --go         # do it
#   bash scripts/tag-release.sh --go --skip-tests
set -euo pipefail

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GO=0
SKIP_TESTS=0
REMOTE="origin"
while [ $# -gt 0 ]; do
  case "$1" in
    --go) GO=1; shift ;;
    --skip-tests) SKIP_TESTS=1; shift ;;
    --remote) REMOTE="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

VERSION=$(awk -F'[ +]' '/^version:/ {print $2; exit}' pubspec.yaml)
[ -n "$VERSION" ] || { echo "Could not read version from pubspec.yaml" >&2; exit 1; }
TAG="v$VERSION"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "version : $VERSION"
echo "tag     : $TAG"
echo "branch  : $BRANCH -> $REMOTE"
echo

# A dirty tree means the release commit doesn't actually contain the work.
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "Working tree has uncommitted tracked changes — commit them first:" >&2
  git status --short --untracked-files=no >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "Tag $TAG already exists locally. Bump the version in pubspec.yaml first." >&2
  exit 1
fi
if git ls-remote --exit-code --tags "$REMOTE" "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists on $REMOTE. Bump the version first." >&2
  exit 1
fi

echo "=== flutter analyze ==="
flutter analyze

if [ "$SKIP_TESTS" -eq 0 ]; then
  echo "=== flutter test ==="
  flutter test
else
  echo "=== flutter test SKIPPED (--skip-tests) ==="
fi

echo
if [ "$GO" -eq 0 ]; then
  echo "DRY RUN — green. Would run:"
  echo "  git push $REMOTE $BRANCH"
  echo "  git tag $TAG && git push $REMOTE $TAG"
  echo "Re-run with --go to publish."
  exit 0
fi

echo "=== pushing $BRANCH ==="
git push "$REMOTE" "$BRANCH"
echo "=== tagging $TAG ==="
git tag "$TAG"
git push "$REMOTE" "$TAG"
echo
echo "Published $TAG. CI release workflow should now be running."
