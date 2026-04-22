#!/usr/bin/env bash
# Validate GitHub Actions workflow YAML files.
# Checks: YAML syntax, optional actionlint, basic policy (permissions block,
# hard-coded "latest" image tags, uses: without pinned version).
# Usage: bash scripts/lint-workflows.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_DIR="$ROOT/.github/workflows"

if [[ ! -d "$WORKFLOW_DIR" ]]; then
  echo "No $WORKFLOW_DIR directory found." >&2
  exit 1
fi

shopt -s nullglob
FILES=("$WORKFLOW_DIR"/*.yml "$WORKFLOW_DIR"/*.yaml)
shopt -u nullglob

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No workflow files found in $WORKFLOW_DIR" >&2
  exit 1
fi

FAIL=0
WARN=0

echo "=== YAML Syntax ==="
for f in "${FILES[@]}"; do
  if ruby -ryaml -e "YAML.load_file(ARGV[0])" "$f" 2>/dev/null; then
    echo "  ok   $(basename "$f")"
  else
    echo "  FAIL $(basename "$f")"
    ruby -ryaml -e "YAML.load_file(ARGV[0])" "$f" || true
    FAIL=$((FAIL + 1))
  fi
done
echo ""

echo "=== actionlint ==="
if command -v actionlint >/dev/null 2>&1; then
  if ! actionlint "${FILES[@]}"; then
    FAIL=$((FAIL + 1))
  else
    echo "  ok"
  fi
else
  echo "  (actionlint not installed; brew install actionlint to enable)"
fi
echo ""

echo "=== Policy Checks ==="
for f in "${FILES[@]}"; do
  base=$(basename "$f")

  # Flag "uses: owner/repo@vX" without a full SHA or explicit version-only tag.
  # Accepts @vN, @vN.M, @vN.M.P, or @<40-char sha>.
  if grep -nE '^\s*-?\s*uses:\s*[^ ]+@(main|master|latest)\s*$' "$f" | grep -v '^$'; then
    echo "  WARN $base: uses: pinned to a moving ref (main/master/latest)"
    WARN=$((WARN + 1))
  fi

  # Flag runs-on: *-latest (prefer pinned ubuntu-24.04 etc. for reproducibility;
  # warning only, many repos prefer -latest intentionally).
  latest_hits=$(grep -cE 'runs-on:\s*[a-z]+-latest' "$f" || true)
  if [[ "$latest_hits" -gt 0 ]]; then
    echo "  note $base: $latest_hits runs-on: *-latest reference(s)"
  fi

  # Top-level permissions block encourages least-privilege tokens.
  if ! grep -qE '^permissions:' "$f"; then
    echo "  WARN $base: no top-level permissions: block (GITHUB_TOKEN has repo defaults)"
    WARN=$((WARN + 1))
  fi
done
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "=== FAILED: $FAIL file(s) have errors, $WARN warning(s) ==="
  exit 1
fi

if [[ $WARN -gt 0 ]]; then
  echo "=== Passed with $WARN warning(s) ==="
else
  echo "=== All workflow checks passed ==="
fi
