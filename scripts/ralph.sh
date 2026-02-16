#!/bin/bash

# Ralph Wiggum Autonomous Development Loop
# =========================================
# Runs Claude Code CLI in a continuous loop, each iteration with a fresh
# context window. Reads PROMPT.md and feeds it to Claude until all tasks
# are complete or max iterations is reached.
#
# Features:
#   - Per-iteration timeout (kills stalled processes)
#   - Progress watchdog (monitors for file changes)
#   - Real-time progress reporting every 30s
#   - Timing per iteration
#
# Usage: ./ralph.sh <max_iterations> [iteration_timeout_seconds]
# Example: ./ralph.sh 20 480
#
# Environment variables:
#   RALPH_ITERATION_TIMEOUT=N   Override per-iteration timeout (default: 480s / 8min)
#   RALPH_STALL_TIMEOUT=N       Kill if no file changes for N seconds (default: 180s / 3min)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Check for required argument
if [ -z "$1" ]; then
  echo -e "${RED}Error: Missing required argument${NC}"
  echo ""
  echo "Usage: $0 <max_iterations> [iteration_timeout_seconds]"
  echo "Example: $0 20 480"
  exit 1
fi

MAX_ITERATIONS=$1
ITERATION_TIMEOUT="${RALPH_ITERATION_TIMEOUT:-${2:-480}}"
STALL_TIMEOUT="${RALPH_STALL_TIMEOUT:-180}"

# Verify required files exist
if [ ! -f "PROMPT.md" ]; then
  echo -e "${RED}Error: PROMPT.md not found${NC}"
  echo "Please generate PROMPT.md first using the Ralph Dev Story (DS) workflow."
  exit 1
fi

if [ ! -f "activity.md" ]; then
  echo -e "${YELLOW}Warning: activity.md not found, creating it...${NC}"
  cat > activity.md << 'EOF'
# Project Build - Activity Log

## Current Status
**Last Updated:** Not started
**Tasks Completed:** 0
**Current Task:** None

---

## Session Log

<!-- Agent will append dated entries here -->
EOF
fi

# Create screenshots directory if it doesn't exist
mkdir -p screenshots

# Temp directory for iteration output
RALPH_TMP=$(mktemp -d)
trap 'rm -rf "$RALPH_TMP"' EXIT

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}   Ralph Wiggum Autonomous Loop${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "Max iterations:       ${GREEN}$MAX_ITERATIONS${NC}"
echo -e "Iteration timeout:    ${GREEN}${ITERATION_TIMEOUT}s ($(( ITERATION_TIMEOUT / 60 ))m)${NC}"
echo -e "Stall timeout:        ${GREEN}${STALL_TIMEOUT}s ($(( STALL_TIMEOUT / 60 ))m)${NC}"
echo -e "Completion signal:    ${GREEN}<promise>COMPLETE</promise>${NC}"
echo ""
echo -e "${YELLOW}Starting in 3 seconds... Press Ctrl+C to abort${NC}"
sleep 3
echo ""

# Take a fingerprint of current file state for change detection
file_fingerprint() {
  # Use git status + modification times of key dirs as a cheap change signal
  {
    git status --short 2>/dev/null
    git diff --stat 2>/dev/null
    find packages services infra -newer "$RALPH_TMP/.watchdog-mark" -type f 2>/dev/null | head -20
  } | md5 2>/dev/null || md5sum 2>/dev/null || echo "no-hash"
}

# Main loop
for ((i=1; i<=MAX_ITERATIONS; i++)); do
  ITER_START=$(date +%s)
  ITER_OUTPUT="$RALPH_TMP/iteration-$i.log"
  touch "$RALPH_TMP/.watchdog-mark"

  echo -e "${BLUE}======================================${NC}"
  echo -e "${BLUE}   Iteration $i of $MAX_ITERATIONS${NC}"
  echo -e "${BLUE}======================================${NC}"
  echo -e "${DIM}Started: $(date '+%H:%M:%S')  Timeout: ${ITERATION_TIMEOUT}s  Stall: ${STALL_TIMEOUT}s${NC}"
  echo ""

  # Capture pre-iteration fingerprint
  PRE_FINGERPRINT=$(file_fingerprint)
  LAST_CHANGE_TIME=$ITER_START

  # Run Claude in background, capture output to file
  claude -p "$(cat PROMPT.md)" --output-format text --dangerously-skip-permissions > "$ITER_OUTPUT" 2>&1 &
  CLAUDE_PID=$!

  # Watchdog loop: monitor for timeout and stalls
  TIMED_OUT=false
  STALLED=false

  while kill -0 "$CLAUDE_PID" 2>/dev/null; do
    NOW=$(date +%s)
    ELAPSED=$(( NOW - ITER_START ))
    SINCE_CHANGE=$(( NOW - LAST_CHANGE_TIME ))

    # Check iteration timeout
    if [ $ELAPSED -ge $ITERATION_TIMEOUT ]; then
      echo ""
      echo -e "${RED}⏱  Iteration timeout (${ITERATION_TIMEOUT}s) — killing claude process${NC}"
      kill "$CLAUDE_PID" 2>/dev/null
      wait "$CLAUDE_PID" 2>/dev/null || true
      TIMED_OUT=true
      break
    fi

    # Check for file changes (stall detection)
    CURRENT_FINGERPRINT=$(file_fingerprint)
    if [ "$CURRENT_FINGERPRINT" != "$PRE_FINGERPRINT" ]; then
      PRE_FINGERPRINT="$CURRENT_FINGERPRINT"
      LAST_CHANGE_TIME=$NOW
      touch "$RALPH_TMP/.watchdog-mark"
    fi

    # Check stall timeout (only after initial grace period of 60s)
    if [ $ELAPSED -gt 60 ] && [ $SINCE_CHANGE -ge $STALL_TIMEOUT ]; then
      echo ""
      echo -e "${RED}⚠  Stall detected — no file changes for ${STALL_TIMEOUT}s — killing claude process${NC}"
      kill "$CLAUDE_PID" 2>/dev/null
      wait "$CLAUDE_PID" 2>/dev/null || true
      STALLED=true
      break
    fi

    # Progress indicator every 30s
    if [ $(( ELAPSED % 30 )) -lt 5 ] && [ $ELAPSED -gt 5 ]; then
      OUTPUT_LINES=$(wc -l < "$ITER_OUTPUT" 2>/dev/null | tr -d ' ')
      GIT_CHANGES=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
      echo -e "${DIM}  [${ELAPSED}s] output: ${OUTPUT_LINES} lines | git changes: ${GIT_CHANGES} | idle: ${SINCE_CHANGE}s/${STALL_TIMEOUT}s${NC}"
    fi

    sleep 5
  done

  # Wait for process to finish (if it completed naturally)
  wait "$CLAUDE_PID" 2>/dev/null || true

  ITER_END=$(date +%s)
  ITER_DURATION=$(( ITER_END - ITER_START ))

  # Read the output
  result=""
  if [ -f "$ITER_OUTPUT" ]; then
    result=$(cat "$ITER_OUTPUT")
  fi

  # Show output (truncated if very large)
  OUTPUT_LINES=$(echo "$result" | wc -l | tr -d ' ')
  if [ "$OUTPUT_LINES" -gt 200 ]; then
    echo ""
    echo -e "${DIM}--- Output (${OUTPUT_LINES} lines, showing last 100) ---${NC}"
    echo "$result" | tail -100
  else
    echo "$result"
  fi
  echo ""

  # Report timing
  echo -e "${CYAN}⏱  Iteration $i completed in ${ITER_DURATION}s ($(( ITER_DURATION / 60 ))m$(( ITER_DURATION % 60 ))s)${NC}"

  if $TIMED_OUT; then
    echo -e "${RED}   Status: TIMEOUT — process killed after ${ITERATION_TIMEOUT}s${NC}"
    echo -e "${YELLOW}   Retrying with fresh context...${NC}"
    echo ""
    sleep 2
    continue
  fi

  if $STALLED; then
    echo -e "${RED}   Status: STALLED — no file changes for ${STALL_TIMEOUT}s${NC}"
    echo -e "${YELLOW}   Retrying with fresh context...${NC}"
    echo ""
    sleep 2
    continue
  fi

  # Check for completion signal
  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}   ALL TASKS COMPLETE!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo -e "Finished after ${GREEN}$i${NC} iteration(s) in ${GREEN}${ITER_DURATION}s${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review the completed work in your project"
    echo "  2. Check activity.md for the full build log"
    echo "  3. Review screenshots/ for visual verification"
    echo "  4. Run your tests to verify everything works"
    echo ""
    exit 0
  fi

  echo ""
  echo -e "${YELLOW}--- End of iteration $i ---${NC}"
  echo ""

  # Small delay between iterations to prevent hammering
  sleep 2
done

echo ""
echo -e "${RED}======================================${NC}"
echo -e "${RED}   MAX ITERATIONS REACHED${NC}"
echo -e "${RED}======================================${NC}"
echo ""
echo -e "Reached max iterations (${RED}$MAX_ITERATIONS${NC}) without completion."
echo ""
echo "Options:"
echo "  1. Run again with more iterations: ./ralph.sh 50"
echo "  2. Check activity.md to see current progress"
echo "  3. Check your story file to see remaining tasks"
echo "  4. Manually complete remaining tasks"
echo ""
exit 1
