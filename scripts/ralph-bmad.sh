#!/bin/bash

# Ralph Wiggum - BMAD Task-Level Executor
# ========================================
# Loops through individual tasks from a BMAD story file, generating a focused
# prompt per task for Claude Code CLI. Each task gets a small, digestible context
# instead of the full story — faster iterations, better reliability.
#
# Flow:
#   1. Parse story → find next task with passes=false
#   2. Generate focused PROMPT.md for that one task
#   3. Run ralph.sh with 1-2 iterations per task
#   4. Verify task passed → move to next task
#   5. After all tasks: run CR gate
#
# Status lifecycle:
#   ready-for-dev → in-progress → [task loop] → [CR gate] → done
#
# Usage: ./ralph-bmad.sh <story_file_path> [max_retries_per_task] [max_cr_iterations]
# Example: ./ralph-bmad.sh _bmad-output/implementation-artifacts/1-2-user-auth.md 3 3
#
# Environment variables:
#   RALPH_ITERATION_TIMEOUT=N   Per-iteration timeout in seconds (default: 480)
#   RALPH_STALL_TIMEOUT=N       Stall detection timeout in seconds (default: 180)
#   CR_MAX_ITERATIONS=N         Max CR iterations (default: 3)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

STORY_FILE="$1"
MAX_RETRIES="${2:-3}"
MAX_CR_ITERATIONS="${CR_MAX_ITERATIONS:-${3:-3}}"
CR_PROMPT_TEMPLATE="cr-prompt.template.md"
TASK_EXTRACTOR="scripts/ralph-extract-task.js"

# Validate arguments
if [ -z "$STORY_FILE" ]; then
  echo -e "${RED}Error: Missing required argument${NC}"
  echo ""
  echo "Usage: $0 <story_file_path> [max_retries_per_task] [max_cr_iterations]"
  echo "Example: $0 _bmad-output/implementation-artifacts/1-2-user-auth.md 3 3"
  exit 1
fi

if [ ! -f "$STORY_FILE" ]; then
  echo -e "${RED}Error: Story file not found: $STORY_FILE${NC}"
  exit 1
fi

if [ ! -f "ralph.sh" ]; then
  echo -e "${RED}Error: ralph.sh not found in project root${NC}"
  exit 1
fi

if [ ! -f "$TASK_EXTRACTOR" ]; then
  echo -e "${RED}Error: $TASK_EXTRACTOR not found${NC}"
  echo "Please ensure the task extractor script exists."
  exit 1
fi

# Extract story key from filename
STORY_KEY=$(basename "$STORY_FILE" .md)

# Find sprint-status.yaml if it exists
SPRINT_STATUS=$(find . -name "sprint-status.yaml" -maxdepth 3 2>/dev/null | head -1)

# Update story and sprint status helper
update_status() {
  local from="$1"
  local to="$2"
  sed -i '' "s/^## Status: $from/## Status: $to/" "$STORY_FILE" 2>/dev/null || \
    sed -i "s/^## Status: $from/## Status: $to/" "$STORY_FILE" 2>/dev/null || true
  if [ -n "$SPRINT_STATUS" ]; then
    if grep -q "${STORY_KEY}: $from" "$SPRINT_STATUS" 2>/dev/null; then
      sed -i '' "s/${STORY_KEY}: $from/${STORY_KEY}: $to/" "$SPRINT_STATUS" 2>/dev/null || \
        sed -i "s/${STORY_KEY}: $from/${STORY_KEY}: $to/" "$SPRINT_STATUS" 2>/dev/null || true
    fi
  fi
}

# Generate focused PROMPT.md for a single task
generate_task_prompt() {
  local task_json="$1"
  local task_id=$(echo "$task_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.taskId)")
  local task_title=$(echo "$task_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.title)")
  local completed=$(echo "$task_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.completedCount)")
  local total=$(echo "$task_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.totalTasks)")
  local steps=$(echo "$task_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));d.steps.forEach((s,i)=>console.log((i+1)+'. '+s))")
  local checks=$(echo "$task_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));d.checkCommands.forEach(c=>console.log(c))")

  cat > PROMPT.md << PROMPT_EOF
@${STORY_FILE} @activity.md

You are implementing task ${task_id} (${completed}/${total} done) from story ${STORY_KEY}.

## Task: ${task_title}

Read the story file above for full context (Dev Notes, architecture patterns, conventions).
Focus ONLY on this one task.

## Steps
${steps}

## Verification
After implementing, run these checks:
\`\`\`bash
npm run build 2>&1 | tail -20
npx vitest run --reporter=verbose 2>&1 | tail -30
npm run lint 2>&1 | tail -10
\`\`\`
${checks:+
Task-specific checks:
\`\`\`bash
${checks}
\`\`\`
}
## After completing the task

1. In the story file, find the Ralph Tasks JSON and set ${task_id}'s "passes" from false to true
2. Mark the corresponding checkbox [x] in the Tasks section
3. Update the File List in the Dev Agent Record section
4. Append a dated progress entry to activity.md
5. Commit: git add -A && git commit -m "feat(${STORY_KEY}): [brief description]"

Do NOT reformat the Ralph Tasks JSON — only change the "passes" field.
Do NOT work on any other task.
Do NOT run git init, change git remotes, or push.

## Completion

When this task is done and verified, output:

<promise>COMPLETE</promise>
PROMPT_EOF
}

# Generate CR-PROMPT.md from template
generate_cr_prompt() {
  sed \
    -e "s|{{story_file_path}}|$STORY_FILE|g" \
    -e "s|{{story_key}}|$STORY_KEY|g" \
    -e "s|{{cr_iteration}}|$CR_ITERATION|g" \
    -e "s|{{max_cr_iterations}}|$MAX_CR_ITERATIONS|g" \
    -e "s|{{date}}|$(date +%Y-%m-%d)|g" \
    "$CR_PROMPT_TEMPLATE" > CR-PROMPT.md
}

# Update story status: ready-for-dev → in-progress
if grep -q "^## Status: ready-for-dev" "$STORY_FILE" 2>/dev/null; then
  update_status "ready-for-dev" "in-progress"
  echo -e "${BLUE}Story status updated: ready-for-dev → in-progress${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Ralph-BMAD Task-Level Executor${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Story:            ${GREEN}$STORY_FILE${NC}"
echo -e "Key:              ${GREEN}$STORY_KEY${NC}"
echo -e "Max retries/task: ${GREEN}$MAX_RETRIES${NC}"
echo -e "Max CR iterations:${GREEN} $MAX_CR_ITERATIONS${NC}"
echo ""

# ========================================
# Phase 1: Task Loop
# ========================================

TASK_FAILURES=0
MAX_TOTAL_FAILURES=5  # Bail out after this many total failures

while true; do
  # Extract next task
  TASK_JSON=$(node "$TASK_EXTRACTOR" "$STORY_FILE" 2>&1)
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error extracting task: $TASK_JSON${NC}"
    exit 1
  fi

  # Check if all tasks are done
  IS_DONE=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.done)")
  if [ "$IS_DONE" = "true" ]; then
    TOTAL=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.totalTasks)")
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   All ${TOTAL} tasks complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    break
  fi

  TASK_ID=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.taskId)")
  TASK_TITLE=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.title)")
  COMPLETED=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.completedCount)")
  TOTAL=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.totalTasks)")

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   Task: ${TASK_ID} (${COMPLETED}/${TOTAL})${NC}"
  echo -e "${BLUE}   ${TASK_TITLE}${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # Try the task up to MAX_RETRIES times
  TASK_PASSED=false
  for ((retry=1; retry<=MAX_RETRIES; retry++)); do
    echo -e "${CYAN}Attempt $retry/$MAX_RETRIES for ${TASK_ID}${NC}"

    # Generate focused prompt for this task
    generate_task_prompt "$TASK_JSON"

    # Run ralph.sh with 1 iteration (the prompt handles one task)
    ./ralph.sh 1 || true

    # Check if the task now passes
    UPDATED_JSON=$(node "$TASK_EXTRACTOR" "$STORY_FILE" 2>&1)
    UPDATED_DONE=$(echo "$UPDATED_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.done)")
    UPDATED_ID=$(echo "$UPDATED_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.done?'':d.taskId)" 2>/dev/null || true)

    if [ "$UPDATED_DONE" = "true" ] || [ "$UPDATED_ID" != "$TASK_ID" ]; then
      # Task passed — the next incomplete task is different or all are done
      echo -e "${GREEN}✓ ${TASK_ID} passed${NC}"
      TASK_PASSED=true
      break
    fi

    echo -e "${YELLOW}  ${TASK_ID} still not passing after attempt $retry${NC}"
    sleep 2
  done

  if ! $TASK_PASSED; then
    TASK_FAILURES=$((TASK_FAILURES + 1))
    echo -e "${RED}✗ ${TASK_ID} failed after $MAX_RETRIES attempts (total failures: $TASK_FAILURES)${NC}"

    if [ $TASK_FAILURES -ge $MAX_TOTAL_FAILURES ]; then
      echo -e "${RED}Too many task failures ($TASK_FAILURES). Stopping.${NC}"
      update_status "in-progress" "review"
      echo -e "${YELLOW}Story marked REVIEW — manual intervention needed.${NC}"
      rm -f PROMPT.md CR-PROMPT.md
      exit 1
    fi

    # Skip this task and try the next one? No — tasks are sequential, we must stop.
    echo -e "${RED}Cannot proceed — tasks must be completed in order.${NC}"
    update_status "in-progress" "review"
    rm -f PROMPT.md CR-PROMPT.md
    exit 1
  fi
done

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
  rm -f PROMPT.md
  exit 0
fi

CR_ITERATION=0
CR_RESULT="CR-FIXED"

while [ "$CR_RESULT" = "CR-FIXED" ] && [ $CR_ITERATION -lt $MAX_CR_ITERATIONS ]; do
  CR_ITERATION=$((CR_ITERATION + 1))

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   CR Iteration $CR_ITERATION of $MAX_CR_ITERATIONS${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  generate_cr_prompt

  cr_output=$(claude -p "$(cat CR-PROMPT.md)" --output-format text --dangerously-skip-permissions 2>&1) || true

  echo "$cr_output"
  echo ""

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

  if [ "$CR_RESULT" = "CR-FIXED" ] && [ $CR_ITERATION -lt $MAX_CR_ITERATIONS ]; then
    echo -e "${YELLOW}Issues were fixed. Re-running CR with fresh context to verify...${NC}"
    sleep 2
  fi
done

# Clean up generated prompts
rm -f CR-PROMPT.md PROMPT.md

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
    echo "  Reason: Max CR iterations ($MAX_CR_ITERATIONS) reached."
  fi
  echo "  Check activity.md for CR findings."
  echo ""
fi

exit 0
