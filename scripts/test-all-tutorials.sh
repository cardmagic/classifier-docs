#!/bin/bash

# Test all classifier tutorials
# Usage: ./test-all-tutorials.sh [--fix]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TUTORIALS_DIR="$SCRIPT_DIR/../src/content/tutorials"
FIX_MODE="$1"

echo "========================================"
echo "Testing all tutorials in: $TUTORIALS_DIR"
echo "========================================"
echo ""

PASS_COUNT=0
FAIL_COUNT=0
FAILED_TUTORIALS=""

for tutorial in "$TUTORIALS_DIR"/*.md; do
  name=$(basename "$tutorial" .md)

  # Skip index files or non-tutorial files
  if [ "$name" == "index" ]; then
    continue
  fi

  echo "Testing: $name"
  echo "----------------------------------------"

  if [ "$FIX_MODE" == "--fix" ]; then
    "$SCRIPT_DIR/test-tutorial.sh" "$tutorial" --fix
  else
    # Capture output and check for PASS/FAIL
    OUTPUT=$("$SCRIPT_DIR/test-tutorial.sh" "$tutorial" 2>&1)
    echo "$OUTPUT"

    if echo "$OUTPUT" | grep -q "STATUS: PASS"; then
      ((PASS_COUNT++))
      echo "✓ $name: PASSED"
    else
      ((FAIL_COUNT++))
      FAILED_TUTORIALS="$FAILED_TUTORIALS $name"
      echo "✗ $name: FAILED"
    fi
  fi

  echo ""
done

if [ "$FIX_MODE" != "--fix" ]; then
  echo "========================================"
  echo "SUMMARY"
  echo "========================================"
  echo "Passed: $PASS_COUNT"
  echo "Failed: $FAIL_COUNT"

  if [ -n "$FAILED_TUTORIALS" ]; then
    echo ""
    echo "Failed tutorials:$FAILED_TUTORIALS"
    echo ""
    echo "Run with --fix to automatically fix failed tutorials:"
    echo "  $0 --fix"
  fi
fi
