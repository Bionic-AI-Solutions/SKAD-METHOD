#!/bin/bash

# Ralph Wiggum - BMAD Story Adapter
# ===================================
# Wraps ralph.sh with BMAD story/sprint status tracking.
# After dev loop completes, runs an automated Code Review (CR) gate
# that adversarially reviews and auto-fixes issues until clean.
#
# Status lifecycle:
#   ready-for-dev → in-progress → [dev loop] → [CR gate] → done
#                                                  ↓
#                                            CR-BLOCKED → review (human needed)
#
# Usage: ./ralph-bmad.sh <story_file_path> [max_iterations] [max_cr_iterations]
# Example: ./ralph-bmad.sh docs/stories/1-2-user-auth.md 20 3
#
# Environment variables:
#   CR_MAX_ITERATIONS=N  Override max CR iterations (default: 3)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

STORY_FILE="$1"
MAX_ITERATIONS="${2:-20}"
MAX_CR_ITERATIONS="${CR_MAX_ITERATIONS:-${3:-3}}"
CR_PROMPT_TEMPLATE="cr-prompt.template.md"

# Validate arguments
if [ -z "$STORY_FILE" ]; then
  echo -e "${RED}Error: Missing required argument${NC}"
  echo ""
  echo "Usage: $0 <story_file_path> [max_iterations] [max_cr_iterations]"
  echo "Example: $0 docs/stories/1-2-user-auth.md 20 3"
  exit 1
fi

if [ ! -f "$STORY_FILE" ]; then
  echo -e "${RED}Error: Story file not found: $STORY_FILE${NC}"
  exit 1
fi

if [ ! -f "ralph.sh" ]; then
  echo -e "${RED}Error: ralph.sh not found in project root${NC}"
  echo "Please ensure ralph.sh is in the project root directory."
  exit 1
fi

if [ ! -f "PROMPT.md" ]; then
  echo -e "${RED}Error: PROMPT.md not found in project root${NC}"
  echo "Please generate PROMPT.md first using the Ralph Dev Story (DS) workflow."
  exit 1
fi

# Extract story key from filename
STORY_KEY=$(basename "$STORY_FILE" .md)

# Find sprint-status.yaml if it exists
SPRINT_STATUS=$(find . -name "sprint-status.yaml" -maxdepth 3 2>/dev/null | head -1)

# Generate CR-PROMPT.md from template with story-specific variables
generate_cr_prompt() {
  sed \
    -e "s|{{story_file_path}}|$STORY_FILE|g" \
    -e "s|{{story_key}}|$STORY_KEY|g" \
    -e "s|{{cr_iteration}}|$CR_ITERATION|g" \
    -e "s|{{max_cr_iterations}}|$MAX_CR_ITERATIONS|g" \
    -e "s|{{date}}|$(date +%Y-%m-%d)|g" \
    "$CR_PROMPT_TEMPLATE" > CR-PROMPT.md
}

# Update story and sprint status helper
update_status() {
  local from="$1"
  local to="$2"
  sed -i '' "s/^Status: $from/Status: $to/" "$STORY_FILE"
  if [ -n "$SPRINT_STATUS" ]; then
    if grep -q "${STORY_KEY}: $from" "$SPRINT_STATUS" 2>/dev/null; then
      sed -i '' "s/${STORY_KEY}: $from/${STORY_KEY}: $to/" "$SPRINT_STATUS"
    fi
  fi
}

# Update story status: ready-for-dev → in-progress
if grep -q "^Status: ready-for-dev" "$STORY_FILE" 2>/dev/null; then
  update_status "ready-for-dev" "in-progress"
  echo -e "${BLUE}Story status updated: ready-for-dev → in-progress${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Ralph-BMAD Story Execution${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Story: ${GREEN}$STORY_FILE${NC}"
echo -e "Key: ${GREEN}$STORY_KEY${NC}"
echo -e "Max dev iterations: ${GREEN}$MAX_ITERATIONS${NC}"
echo -e "Max CR iterations:  ${GREEN}$MAX_CR_ITERATIONS${NC}"
echo ""

# ========================================
# Phase 1: Dev Loop
# ========================================

./ralph.sh "$MAX_ITERATIONS"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo -e "${RED}Dev loop did not complete. Story remains in-progress.${NC}"
  exit $EXIT_CODE
fi

# ========================================
# Phase 2: Code Review Gate
# ========================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Dev loop complete. Entering CR gate${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if CR template exists; if not, fall back to marking review
if [ ! -f "$CR_PROMPT_TEMPLATE" ]; then
  echo -e "${YELLOW}Warning: $CR_PROMPT_TEMPLATE not found. Skipping CR gate.${NC}"
  update_status "in-progress" "review"
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}   Story Status: review${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Run code-review (CR) workflow manually"
  echo "  2. Check activity.md for the full iteration log"
  echo ""
  exit 0
fi

CR_ITERATION=0
CR_RESULT="CR-FIXED"  # Start assuming we need to run

while [ "$CR_RESULT" = "CR-FIXED" ] && [ $CR_ITERATION -lt $MAX_CR_ITERATIONS ]; do
  CR_ITERATION=$((CR_ITERATION + 1))

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   CR Iteration $CR_ITERATION of $MAX_CR_ITERATIONS${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # Generate CR-PROMPT.md from template
  generate_cr_prompt

  # Run Claude with CR prompt (fresh context each time)
  cr_output=$(claude -p "$(cat CR-PROMPT.md)" --output-format text --dangerously-skip-permissions 2>&1) || true

  echo "$cr_output"
  echo ""

  # Detect CR signal from output
  if [[ "$cr_output" == *"<cr-signal>CR-PASS</cr-signal>"* ]]; then
    CR_RESULT="CR-PASS"
  elif [[ "$cr_output" == *"<cr-signal>CR-FIXED</cr-signal>"* ]]; then
    CR_RESULT="CR-FIXED"
  elif [[ "$cr_output" == *"<cr-signal>CR-BLOCKED</cr-signal>"* ]]; then
    CR_RESULT="CR-BLOCKED"
  else
    echo -e "${RED}CR agent did not emit a recognized signal. Treating as CR-BLOCKED.${NC}"
    CR_RESULT="CR-BLOCKED"
  fi

  echo -e "${YELLOW}CR Result: $CR_RESULT${NC}"
  echo ""

  # If fixes were applied and we have iterations left, re-run with fresh context
  if [ "$CR_RESULT" = "CR-FIXED" ] && [ $CR_ITERATION -lt $MAX_CR_ITERATIONS ]; then
    echo -e "${YELLOW}Issues were fixed. Re-running CR with fresh context to verify...${NC}"
    sleep 2
  fi
done

# Clean up generated prompt
rm -f CR-PROMPT.md

# ========================================
# Phase 3: Final Status Update
# ========================================

if [ "$CR_RESULT" = "CR-PASS" ]; then
  update_status "in-progress" "done"
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}   Story DONE! CR passed after $CR_ITERATION iteration(s)${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "  All HIGH and MEDIUM issues resolved."
  echo "  Check activity.md for the full dev + CR log."
  echo ""
else
  update_status "in-progress" "review"
  echo ""
  echo -e "${YELLOW}========================================${NC}"
  echo -e "${YELLOW}   Story marked REVIEW — human intervention needed${NC}"
  echo -e "${YELLOW}========================================${NC}"
  echo ""
  if [ "$CR_RESULT" = "CR-BLOCKED" ]; then
    echo "  Reason: CR agent reported issues it cannot auto-fix."
  else
    echo "  Reason: Max CR iterations ($MAX_CR_ITERATIONS) reached with issues still being fixed."
  fi
  echo "  Next: Run code-review (CR) workflow manually."
  echo "  Check activity.md for CR findings."
  echo ""
fi

exit 0
