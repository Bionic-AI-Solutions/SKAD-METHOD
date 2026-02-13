#!/bin/bash

# Ralph Wiggum - BMAD Story Adapter
# ===================================
# Wraps ralph.sh with BMAD story/sprint status tracking.
# Updates story status through the lifecycle:
#   ready-for-dev → in-progress → review
#
# Usage: ./ralph-bmad.sh <story_file_path> [max_iterations]
# Example: ./ralph-bmad.sh docs/stories/1-2-user-auth.md 20

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

STORY_FILE="$1"
MAX_ITERATIONS="${2:-20}"

# Validate arguments
if [ -z "$STORY_FILE" ]; then
  echo -e "${RED}Error: Missing required argument${NC}"
  echo ""
  echo "Usage: $0 <story_file_path> [max_iterations]"
  echo "Example: $0 docs/stories/1-2-user-auth.md 20"
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

# Update story status: ready-for-dev → in-progress
if grep -q "^Status: ready-for-dev" "$STORY_FILE" 2>/dev/null; then
  sed -i 's/^Status: ready-for-dev/Status: in-progress/' "$STORY_FILE"
  echo -e "${BLUE}Story status updated: ready-for-dev → in-progress${NC}"
fi

# Update sprint-status.yaml if it exists
if [ -n "$SPRINT_STATUS" ]; then
  if grep -q "${STORY_KEY}: ready-for-dev" "$SPRINT_STATUS" 2>/dev/null; then
    sed -i "s/${STORY_KEY}: ready-for-dev/${STORY_KEY}: in-progress/" "$SPRINT_STATUS"
    echo -e "${BLUE}Sprint status updated: $STORY_KEY → in-progress${NC}"
  fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Ralph-BMAD Story Execution${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Story: ${GREEN}$STORY_FILE${NC}"
echo -e "Key: ${GREEN}$STORY_KEY${NC}"
echo -e "Max iterations: ${GREEN}$MAX_ITERATIONS${NC}"
echo ""

# Run the ralph loop
./ralph.sh "$MAX_ITERATIONS"
EXIT_CODE=$?

# If complete, update story status to review
if [ $EXIT_CODE -eq 0 ]; then
  sed -i 's/^Status: in-progress/Status: review/' "$STORY_FILE"

  if [ -n "$SPRINT_STATUS" ]; then
    if grep -q "${STORY_KEY}: in-progress" "$SPRINT_STATUS" 2>/dev/null; then
      sed -i "s/${STORY_KEY}: in-progress/${STORY_KEY}: review/" "$SPRINT_STATUS"
    fi
  fi

  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}   Story Complete! Status: review${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review the implementation in $STORY_FILE"
  echo "  2. Check activity.md for the full iteration log"
  echo "  3. Run code-review (CR) workflow for peer review"
  echo "  4. Optional: Run QA workflow for additional test coverage"
  echo ""
fi

exit $EXIT_CODE
