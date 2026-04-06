#!/usr/bin/env bash
# Validate: static analysis + tests
# Usage: bash scripts/validate.sh
set -euo pipefail

echo "=== Static Analysis ==="
flutter analyze --fatal-infos
echo ""

echo "=== Running Tests ==="
flutter test
echo ""

echo "=== All checks passed ==="
