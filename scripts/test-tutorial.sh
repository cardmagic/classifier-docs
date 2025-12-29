#!/bin/bash

# Test and optionally fix classifier tutorials
# Usage: ./test-tutorial.sh <path-to-tutorial.md> [--fix]

set -e

TUTORIAL_PATH="$1"
FIX_MODE="$2"

if [ -z "$TUTORIAL_PATH" ]; then
  echo "Usage: $0 <path-to-tutorial.md> [--fix]"
  echo ""
  echo "Examples:"
  echo "  $0 ~/Sites/personal/classifier-docs/src/content/tutorials/spam-filter.md"
  echo "  $0 ~/Sites/personal/classifier-docs/src/content/tutorials/spam-filter.md --fix"
  exit 1
fi

if [ ! -f "$TUTORIAL_PATH" ]; then
  echo "Error: File not found: $TUTORIAL_PATH"
  exit 1
fi

TUTORIAL_NAME=$(basename "$TUTORIAL_PATH" .md)
CLASSIFIER_DIR="$HOME/Sites/personal/classifier"

# Ensure we're using the classifier gem
if [ ! -d "$CLASSIFIER_DIR" ]; then
  echo "Error: Classifier directory not found at $CLASSIFIER_DIR"
  exit 1
fi

if [ "$FIX_MODE" == "--fix" ]; then
  # Fix mode: have Claude fix the tutorial
  echo "Fixing tutorial: $TUTORIAL_NAME"
  echo "========================================"

  claude --dangerously-skip-permissions -p "You are testing a Ruby classifier gem tutorial for accuracy.

Working directory for running Ruby code: $CLASSIFIER_DIR (run 'cd $CLASSIFIER_DIR && bundle exec ruby ...')

Tutorial file: $TUTORIAL_PATH

Your task:
1. Read the tutorial markdown file
2. Extract ALL Ruby code examples from the tutorial
3. Create a test script that runs ALL the examples together (combining classes, training data, and test code)
4. Run the test script using 'cd $CLASSIFIER_DIR && bundle exec ruby /tmp/tutorial_test.rb'
5. Compare the actual output with the documented output in the tutorial
6. If there are differences, update the tutorial file to match the REAL output
7. Keep code examples unchanged - only update the expected output sections
8. Add helpful notes if the output differs significantly from what users might expect

Important:
- Use the Edit tool to update the tutorial file directly
- Preserve all markdown formatting
- Only change output examples, not the Ruby code itself
- If the code has bugs that prevent it from running, report what needs to be fixed

After fixing, confirm what changes were made."

else
  # Test mode: check if tutorial works
  echo "Testing tutorial: $TUTORIAL_NAME"
  echo "========================================"

  claude --dangerously-skip-permissions -p "You are testing a Ruby classifier gem tutorial for accuracy.

Working directory for running Ruby code: $CLASSIFIER_DIR (run 'cd $CLASSIFIER_DIR && bundle exec ruby ...')

Tutorial file: $TUTORIAL_PATH

Your task:
1. Read the tutorial markdown file
2. Extract ALL Ruby code examples from the tutorial
3. Create a comprehensive test script at /tmp/tutorial_test.rb that runs the examples
4. Run: cd $CLASSIFIER_DIR && bundle exec ruby /tmp/tutorial_test.rb
5. Compare actual output with documented output in the tutorial

Report your findings in this format:

TUTORIAL: <name>
STATUS: PASS or FAIL
ISSUES: (if any)
- List each discrepancy between documented and actual output
- Note any code that fails to run

If STATUS is PASS, the tutorial accurately reflects real output.
If STATUS is FAIL, the tutorial needs updating with --fix flag.

Be thorough - test ALL code examples in the tutorial, not just the first one."

fi
