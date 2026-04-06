#!/usr/bin/env bash
# Pre-push quality gate: sensitive files check + analysis + tests
# Usage: bash scripts/pre-push.sh
set -euo pipefail

WARNINGS=0

echo "=== Checking for Sensitive Files ==="

# Check if key files are staged
if git diff --cached --name-only 2>/dev/null | grep -qE '^key(\.pub)?$'; then
  echo "WARNING: SSH key files (key/key.pub) are staged for commit!"
  echo "  Consider adding them to .gitignore"
  WARNINGS=$((WARNINGS + 1))
fi

# Check if key files exist and aren't in .gitignore
for f in key key.pub; do
  if [ -f "$f" ] && ! git check-ignore -q "$f" 2>/dev/null; then
    echo "WARNING: $f exists but is NOT in .gitignore"
    WARNINGS=$((WARNINGS + 1))
  fi
done

# Check for .env files
if git ls-files --others --exclude-standard | grep -qE '\.env'; then
  echo "WARNING: Untracked .env files found"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

echo "=== Checking Uncommitted Changes ==="
UNSTAGED=$(git diff --stat 2>/dev/null)
if [ -n "$UNSTAGED" ]; then
  echo "NOTE: You have unstaged changes. Tests will run against the working tree."
  echo "$UNSTAGED"
  echo ""
fi

echo "=== Static Analysis ==="
flutter analyze --fatal-infos
echo ""

echo "=== Running Tests ==="
flutter test
echo ""

if [ "$WARNINGS" -gt 0 ]; then
  echo "=== All checks passed with $WARNINGS warning(s) ==="
else
  echo "=== All checks passed. Safe to push. ==="
fi
