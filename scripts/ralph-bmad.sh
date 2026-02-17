#!/bin/bash

# Ralph Wiggum - BMAD Autonomous Pipeline
# ========================================
# Autonomous story-chaining pipeline that discovers, executes, validates,
# reviews, and chains BMAD stories without human intervention.
#
# Phase Flow:
#   Phase 0: Discover next story from sprint-status.yaml
#   Phase 1: Task loop (per-task retry, auto-verify, failure learnings)
#   Phase 2: Story validation (full build + test suite)
#   Phase 3: CR gate (adversarial code review)
#   Phase 4: Epic validation (when all stories in epic are done)
#   Phase 5: CS — auto-create next story from backlog
#   Phase 6: Chain — loop back to Phase 0
#
# Usage: ./ralph-bmad.sh [story_file] [max_retries_per_task] [max_cr_iterations]
#        ./ralph-bmad.sh                    # Auto-detect + chain mode
#        ./ralph-bmad.sh story.md 3 3       # Single story (explicit)
#
# Environment variables:
#   RALPH_ITERATION_TIMEOUT=N     Per-iteration timeout (default: 480s)
#   RALPH_STALL_TIMEOUT=N         Stall detection timeout (default: 180s)
#   RALPH_WALL_CLOCK_TIMEOUT=N    Total run wall-clock timeout (default: 3600s)
#   RALPH_CHAIN_MODE=true|false   Enable story chaining (default: true)
#   RALPH_SKIP_CS=true|false      Skip auto Create Story (default: false)
#   RALPH_SKIP_VALIDATION=true|false  Skip story/epic validation (default: false)
#   CR_MAX_ITERATIONS=N           Max CR iterations (default: 3)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Configuration
MAX_RETRIES="${2:-3}"
MAX_CR_ITERATIONS="${CR_MAX_ITERATIONS:-${3:-3}}"
CR_PROMPT_TEMPLATE="cr-prompt.template.md"
CS_PROMPT_TEMPLATE="cs-prompt.template.md"
TASK_EXTRACTOR="scripts/ralph-extract-task.js"
SPRINT_STATUS_TOOL="scripts/ralph-sprint-status.js"
PROGRESS_REPORT="ralph-progress.md"

# Feature flags
CHAIN_MODE="${RALPH_CHAIN_MODE:-true}"
SKIP_CS="${RALPH_SKIP_CS:-false}"
SKIP_VALIDATION="${RALPH_SKIP_VALIDATION:-false}"

# Wall-clock timeout: kill entire run after this many seconds (default: 1 hour)
WALL_CLOCK_TIMEOUT="${RALPH_WALL_CLOCK_TIMEOUT:-3600}"
RUN_START=$(date +%s)

# Timeline events for progress report
TIMELINE_EVENTS=""

# If story file explicitly provided, disable chaining (single-story mode)
EXPLICIT_STORY=""
if [ -n "$1" ] && [ -f "$1" ]; then
  EXPLICIT_STORY="$1"
  CHAIN_MODE="false"
fi

# Validate required scripts exist
if [ ! -f "ralph.sh" ]; then
  echo -e "${RED}Error: ralph.sh not found in project root${NC}"
  exit 1
fi

if [ ! -f "$TASK_EXTRACTOR" ]; then
  echo -e "${RED}Error: $TASK_EXTRACTOR not found${NC}"
  exit 1
fi

if [ ! -f "$SPRINT_STATUS_TOOL" ]; then
  echo -e "${RED}Error: $SPRINT_STATUS_TOOL not found${NC}"
  exit 1
fi

# ========================================
# Utility Functions
# ========================================

# Find sprint-status.yaml
find_sprint_status() {
  local path=$(find . -name "sprint-status.yaml" -maxdepth 3 2>/dev/null | head -1)
  echo "${path:-./_bmad-output/implementation-artifacts/sprint-status.yaml}"
}

SPRINT_STATUS=$(find_sprint_status)

# Update story and sprint status helper
update_status() {
  local from="$1"
  local to="$2"
  sed -i '' "s/^Status: $from/Status: $to/" "$STORY_FILE" 2>/dev/null || \
    sed -i "s/^Status: $from/Status: $to/" "$STORY_FILE" 2>/dev/null || true
  if [ -n "$SPRINT_STATUS" ] && [ -f "$SPRINT_STATUS" ]; then
    if grep -q "${STORY_KEY}: $from" "$SPRINT_STATUS" 2>/dev/null; then
      sed -i '' "s/${STORY_KEY}: $from/${STORY_KEY}: $to/" "$SPRINT_STATUS" 2>/dev/null || \
        sed -i "s/${STORY_KEY}: $from/${STORY_KEY}: $to/" "$SPRINT_STATUS" 2>/dev/null || true
    fi
  fi
}

# Check wall-clock timeout
check_wall_clock() {
  local now=$(date +%s)
  local elapsed=$(( now - RUN_START ))
  if [ $elapsed -ge $WALL_CLOCK_TIMEOUT ]; then
    echo -e "${RED}Wall-clock timeout reached (${elapsed}s >= ${WALL_CLOCK_TIMEOUT}s). Stopping.${NC}"
    if [ -n "$STORY_FILE" ] && [ -f "$STORY_FILE" ]; then
      update_status "in-progress" "review"
      echo -e "${YELLOW}Story marked REVIEW — wall-clock timeout.${NC}"
    fi
    add_timeline_event "Wall-clock timeout reached (${elapsed}s)"
    update_progress_report "Wall-clock timeout"
    rm -f PROMPT.md CR-PROMPT.md CS-PROMPT.md
    exit 1
  fi
}

# Add a timeline event
add_timeline_event() {
  local event="$1"
  local ts=$(date '+%H:%M:%S')
  TIMELINE_EVENTS="- ${ts} — ${event}
${TIMELINE_EVENTS}"
}

# ========================================
# Auto-Verify via checkCommands
# ========================================

auto_verify_task() {
  local task_json="$1"
  local task_id=$(echo "$task_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.taskId)")

  local check_cmds=$(echo "$task_json" | node -e "
    const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    (d.checkCommands||[]).forEach(c=>console.log(c))
  ")

  if [ -z "$check_cmds" ]; then
    echo -e "${YELLOW}  No checkCommands for ${task_id} — cannot auto-verify${NC}"
    return 1
  fi

  echo -e "${CYAN}  Auto-verifying ${task_id} via checkCommands...${NC}"

  local all_passed=true
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    echo -e "${DIM}    Running: ${cmd}${NC}"
    if (eval "$cmd") > /dev/null 2>&1; then
      echo -e "${DIM}    ✓ passed${NC}"
    else
      echo -e "${DIM}    ✗ failed${NC}"
      all_passed=false
      break
    fi
  done <<< "$check_cmds"

  if $all_passed; then
    echo -e "${GREEN}  All checkCommands passed — auto-marking ${task_id} as passes=true${NC}"
    node -e "
      const fs = require('fs');
      const file = process.argv[1];
      const taskId = process.argv[2];
      let content = fs.readFileSync(file, 'utf-8');
      const jsonMatch = content.match(/## Ralph Tasks JSON[\s\S]*?\\\`\\\`\\\`json\n([\s\S]*?)\n\\\`\\\`\\\`/);
      if (!jsonMatch) { process.exit(1); }
      const tasks = JSON.parse(jsonMatch[1]);
      const task = tasks.find(t => t.id === taskId);
      if (task) {
        task.passes = true;
        const newJson = JSON.stringify(tasks, null, 2);
        content = content.replace(jsonMatch[1], () => newJson);
        fs.writeFileSync(file, content);
        console.log('Updated ' + taskId + ' passes to true');
      }
    " "$STORY_FILE" "$task_id"
    return 0
  else
    return 1
  fi
}

# ========================================
# Failure Learnings Extraction
# ========================================

extract_failure_learnings() {
  local log_file="$1"
  local task_id="$2"
  local attempt="$3"

  if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
    echo "No iteration log available for analysis."
    return
  fi

  echo -e "${CYAN}  Extracting failure learnings from attempt $attempt...${NC}"

  local learnings=""
  learnings=$(timeout 30 claude -p "Analyze this Ralph iteration log for task ${task_id}. In 3-5 concise bullet points, summarize: what was attempted, what failed or went wrong, what should be avoided on retry. Be brief — this will be injected into the next attempt's prompt.

Log (last 200 lines):
$(tail -200 "$log_file")" --output-format text 2>/dev/null) || true

  if [ -z "$learnings" ]; then
    learnings="(Auto-analysis failed. Raw log tail:)
$(tail -20 "$log_file")"
  fi

  if [ -n "$LOG_DIR" ]; then
    {
      echo ""
      echo "### ${task_id} attempt ${attempt} — $(date '+%Y-%m-%d %H:%M:%S')"
      echo "$learnings"
    } >> "$LOG_DIR/failure-learnings.md"
  fi

  echo "$learnings"
}

# Clean up verbose logs for a task after it passes
cleanup_task_logs() {
  local task_id="$1"
  if [ -n "$LOG_DIR" ] && [ -d "$LOG_DIR" ]; then
    rm -f "$LOG_DIR/${task_id}"-*.log "$LOG_DIR/${task_id}"-*-prompt.md 2>/dev/null || true
    echo -e "${DIM}  Cleaned up verbose logs for ${task_id}${NC}"
  fi
}

# ========================================
# Generate Task Prompt
# ========================================

generate_task_prompt() {
  local task_json="$1"
  local failure_context="${2:-}"
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
${failure_context:+

## Previous Attempt Failures
Do NOT repeat these mistakes. Try a DIFFERENT approach:
${failure_context}
}

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
**IMPORTANT — Verification approach:** If tests or build fail, fix them — you have time as long as you're making progress. But if you find yourself going in circles (trying the same fix repeatedly, or reverting back and forth), STOP and proceed to "Mark Complete & Commit" below. The orchestrator will retry with fresh context and learnings from this attempt. Progress means: each fix-and-rerun cycle reduces the number of failing tests or fixes a different issue.

**CRITICAL — Test integrity rules (DO NOT VIOLATE):**
- Fix the CODE under test, never weaken or rewrite the test to make it pass
- NEVER add mocks, stubs, or fakes to tests that are designed to validate real/live integrations — if an integration test fails because the real service call fails, fix the integration code, not the test
- NEVER remove test cases, lower assertion thresholds, or broaden expected values just to get a green result
- NEVER replace real HTTP calls with mocked responses in integration tests — the test exists to validate the actual integration works
- If a unit test expects specific behavior, the fix belongs in the source module, not in the test expectations
- Exception: you MAY fix genuinely broken test setup (wrong import paths, missing test fixtures, incorrect test config) — but the ASSERTIONS and INTENT of the test must remain unchanged

**IMPORTANT — Regression:** Always run the FULL test suite (\`npx vitest run\`), not just the tests for this task. Everything that passed before must continue to pass. If a previous test breaks because of your changes, fix your code to maintain backward compatibility.

## Mark Complete & Commit

**You MUST complete ALL of these steps before your session ends.** This is the most critical part — skipping these causes the orchestrator to retry the entire task from scratch.

1. In the story file, find the Ralph Tasks JSON block and set ${task_id}'s \`"passes"\` from \`false\` to \`true\`
2. Mark the corresponding checkbox \`[x]\` in the Tasks section
3. Update the File List in the Dev Agent Record section
4. Append a dated progress entry to activity.md
5. Commit: \`git add -A && git commit -m "feat(${STORY_KEY}): [brief description]"\`

Do NOT reformat the Ralph Tasks JSON — only change the "passes" field.
Do NOT work on any other task.
Do NOT run git init, change git remotes, or push.

## Completion

When this task is done, output:

<promise>COMPLETE</promise>
PROMPT_EOF
}

# ========================================
# Generate CR Prompt
# ========================================

generate_cr_prompt() {
  sed \
    -e "s|{{story_file_path}}|$STORY_FILE|g" \
    -e "s|{{story_key}}|$STORY_KEY|g" \
    -e "s|{{cr_iteration}}|$CR_ITERATION|g" \
    -e "s|{{max_cr_iterations}}|$MAX_CR_ITERATIONS|g" \
    -e "s|{{date}}|$(date +%Y-%m-%d)|g" \
    "$CR_PROMPT_TEMPLATE" > CR-PROMPT.md
}

# ========================================
# Generate CS Prompt
# ========================================

generate_cs_prompt() {
  local story_key="$1"
  local epic_num="$2"
  local story_num="$3"
  sed \
    -e "s|{{story_key}}|$story_key|g" \
    -e "s|{{epic_num}}|$epic_num|g" \
    -e "s|{{story_num}}|$story_num|g" \
    "$CS_PROMPT_TEMPLATE" > CS-PROMPT.md
}

# ========================================
# Progress Report
# ========================================

update_progress_report() {
  local current_phase="${1:-}"
  local now=$(date +%s)
  local elapsed=$(( now - RUN_START ))
  local elapsed_min=$(( elapsed / 60 ))
  local elapsed_sec=$(( elapsed % 60 ))

  # Build epic/story table using sprint-status tool
  local report_body=""
  report_body=$(node "$SPRINT_STATUS_TOOL" progress-report "${STORY_KEY:-}" 2>/dev/null) || report_body="(Sprint status unavailable)"

  cat > "$PROGRESS_REPORT" << REPORT_EOF
# Ralph Progress Report
**Updated:** $(date '+%Y-%m-%d %H:%M:%S') | **Runtime:** ${elapsed_min}m ${elapsed_sec}s

## Current Activity
**Story:** ${STORY_KEY:-none} | **Phase:** ${current_phase:-Idle}

## Sprint Progress

${report_body}

## Timeline
${TIMELINE_EVENTS:-No events yet.}
REPORT_EOF
}

# ========================================
# Phase 0: Discover Next Story
# ========================================

discover_next_story() {
  if [ -n "$EXPLICIT_STORY" ]; then
    STORY_FILE="$EXPLICIT_STORY"
    STORY_KEY=$(basename "$STORY_FILE" .md)
    echo -e "${BLUE}Using explicit story: $STORY_FILE${NC}"
    return 0
  fi

  echo -e "${CYAN}Discovering next story from sprint-status.yaml...${NC}"

  local result=$(node "$SPRINT_STATUS_TOOL" next-story 2>&1)
  local is_done=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.done)")
  local needs_cs=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.needsCS||false)")

  if [ "$is_done" = "true" ]; then
    echo -e "${GREEN}All stories complete! No more work to do.${NC}"
    return 1
  fi

  local story_key=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.storyKey)")
  local story_status=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.status)")
  local file_path=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.filePath)")

  if [ "$needs_cs" = "true" ] || [ ! -f "$file_path" ]; then
    echo -e "${YELLOW}Next story ${story_key} needs CS (Create Story) first.${NC}"
    NEEDS_CS_KEY="$story_key"
    NEEDS_CS_EPIC=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.epicNum)")
    NEEDS_CS_STORY=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.storyNum)")
    return 2  # Needs CS
  fi

  STORY_FILE="$file_path"
  STORY_KEY="$story_key"
  echo -e "${GREEN}Discovered: $STORY_KEY ($story_status)${NC}"
  return 0
}

# ========================================
# Phase 1: Task Loop
# ========================================

run_task_loop() {
  local TASK_FAILURES=0
  local MAX_TOTAL_FAILURES=5
  local LAST_FAILED_TASK_ID=""

  while true; do
    check_wall_clock

    TASK_JSON=$(node "$TASK_EXTRACTOR" "$STORY_FILE" 2>&1)
    if [ $? -ne 0 ]; then
      echo -e "${RED}Error extracting task: $TASK_JSON${NC}"
      return 1
    fi

    IS_DONE=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.done)")
    if [ "$IS_DONE" = "true" ]; then
      TOTAL=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.totalTasks)")
      echo ""
      echo -e "${GREEN}========================================${NC}"
      echo -e "${GREEN}   All ${TOTAL} tasks complete!${NC}"
      echo -e "${GREEN}========================================${NC}"
      echo ""
      add_timeline_event "Story ${STORY_KEY}: all tasks complete"
      update_progress_report "All tasks complete"
      return 0
    fi

    TASK_ID=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.taskId)")
    TASK_TITLE=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.title)")
    COMPLETED=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.completedCount)")
    TOTAL=$(echo "$TASK_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.totalTasks)")

    # Same-task stuck detection
    if [ "$TASK_ID" = "$LAST_FAILED_TASK_ID" ]; then
      echo -e "${RED}Same task ${TASK_ID} extracted again after failure — stuck loop detected.${NC}"
      add_timeline_event "Stuck loop detected on ${TASK_ID}"
      return 1
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Task: ${TASK_ID} (${COMPLETED}/${TOTAL})${NC}"
    echo -e "${BLUE}   ${TASK_TITLE}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    add_timeline_event "Task ${STORY_KEY}/${TASK_ID} started"
    update_progress_report "Task ${TASK_ID} (${COMPLETED}/${TOTAL})"

    TASK_PASSED=false
    TASK_FAILURE_CONTEXT=""
    for ((retry=1; retry<=MAX_RETRIES; retry++)); do
      check_wall_clock
      echo -e "${CYAN}Attempt $retry/$MAX_RETRIES for ${TASK_ID}${NC}"

      generate_task_prompt "$TASK_JSON" "$TASK_FAILURE_CONTEXT"
      cp PROMPT.md "$LOG_DIR/${TASK_ID}-attempt-${retry}-prompt.md" 2>/dev/null || true

      export RALPH_LOG_DIR="$LOG_DIR"
      # Bump stall timeout for test tasks (agent needs longer read phase)
      local lower_title=$(echo "$TASK_TITLE" | tr '[:upper:]' '[:lower:]')
      if echo "$lower_title" | grep -qE 'test|integration|unit'; then
        RALPH_STALL_TIMEOUT=300 ./ralph.sh 1 || true
      else
        ./ralph.sh 1 || true
      fi

      # Step 1: Check if the task now passes
      UPDATED_JSON=$(node "$TASK_EXTRACTOR" "$STORY_FILE" 2>&1)
      UPDATED_DONE=$(echo "$UPDATED_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.done)")
      UPDATED_ID=$(echo "$UPDATED_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.done?'':d.taskId)" 2>/dev/null || true)

      if [ "$UPDATED_DONE" = "true" ] || [ "$UPDATED_ID" != "$TASK_ID" ]; then
        echo -e "${GREEN}✓ ${TASK_ID} passed${NC}"
        TASK_PASSED=true
        cleanup_task_logs "$TASK_ID"
        add_timeline_event "Task ${STORY_KEY}/${TASK_ID} passed"
        update_progress_report "Task ${TASK_ID} passed"
        break
      fi

      # Step 2: Auto-verify
      if auto_verify_task "$TASK_JSON"; then
        echo -e "${GREEN}✓ ${TASK_ID} auto-verified and marked passing${NC}"
        TASK_PASSED=true
        cleanup_task_logs "$TASK_ID"
        add_timeline_event "Task ${STORY_KEY}/${TASK_ID} auto-verified"
        update_progress_report "Task ${TASK_ID} auto-verified"
        break
      fi

      # Step 3: Extract learnings
      ITER_LOG="$LOG_DIR/iteration-1.log"
      echo -e "${YELLOW}  ${TASK_ID} still not passing after attempt $retry${NC}"
      TASK_FAILURE_CONTEXT=$(extract_failure_learnings "$ITER_LOG" "$TASK_ID" "$retry")
      add_timeline_event "Task ${STORY_KEY}/${TASK_ID} failed attempt $retry"

      sleep 2
    done

    if ! $TASK_PASSED; then
      LAST_FAILED_TASK_ID="$TASK_ID"
      TASK_FAILURES=$((TASK_FAILURES + 1))
      echo -e "${RED}✗ ${TASK_ID} failed after $MAX_RETRIES attempts (total failures: $TASK_FAILURES)${NC}"
      add_timeline_event "Task ${STORY_KEY}/${TASK_ID} FAILED after $MAX_RETRIES attempts"

      if [ $TASK_FAILURES -ge $MAX_TOTAL_FAILURES ]; then
        echo -e "${RED}Too many task failures ($TASK_FAILURES). Stopping.${NC}"
      fi

      return 1
    fi
  done
}

# ========================================
# Phase 2: Story Validation
# ========================================

validate_story() {
  if [ "$SKIP_VALIDATION" = "true" ]; then
    echo -e "${YELLOW}Skipping story validation (RALPH_SKIP_VALIDATION=true)${NC}"
    return 0
  fi

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   Phase 2: Story Validation${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  add_timeline_event "Story ${STORY_KEY}: validation started"
  update_progress_report "Story Validation"

  # Run full build
  echo -e "${CYAN}Running full build...${NC}"
  if ! npm run build 2>&1 | tail -20; then
    echo -e "${RED}Build failed during story validation${NC}"
    add_timeline_event "Story ${STORY_KEY}: build FAILED"
    return 1
  fi
  echo -e "${GREEN}✓ Build passed${NC}"

  # Run full test suite
  echo -e "${CYAN}Running full test suite...${NC}"
  if ! npx vitest run --reporter=verbose 2>&1 | tail -50; then
    echo -e "${RED}Tests failed during story validation${NC}"
    add_timeline_event "Story ${STORY_KEY}: tests FAILED"
    return 1
  fi
  echo -e "${GREEN}✓ Tests passed${NC}"

  # Run story-specific validation commands if they exist
  if grep -q "## Story Validation" "$STORY_FILE" 2>/dev/null; then
    echo -e "${CYAN}Running story-specific validation commands...${NC}"
    local validation_cmds=$(node -e "
      const fs = require('fs');
      const content = fs.readFileSync(process.argv[1], 'utf-8');
      const match = content.match(/## Story Validation[\s\S]*?\\\`\\\`\\\`bash\n([\s\S]*?)\n\\\`\\\`\\\`/);
      if (match) {
        const cmds = match[1].split('\n').filter(l => l.trim() && !l.trim().startsWith('#'));
        cmds.forEach(c => console.log(c));
      }
    " "$STORY_FILE" 2>/dev/null)

    if [ -n "$validation_cmds" ]; then
      while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        echo -e "${DIM}  Running: ${cmd}${NC}"
        if ! (eval "$cmd") 2>&1 | tail -20; then
          echo -e "${RED}Story validation command failed: ${cmd}${NC}"
          add_timeline_event "Story ${STORY_KEY}: validation command FAILED"
          return 1
        fi
      done <<< "$validation_cmds"
    fi
  fi

  echo -e "${GREEN}✓ Story validation passed${NC}"
  add_timeline_event "Story ${STORY_KEY}: validation passed"
  update_progress_report "Story Validation Passed"
  return 0
}

# ========================================
# Phase 3: CR Gate
# ========================================

run_cr_gate() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   Phase 3: Code Review Gate${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  if [ ! -f "$CR_PROMPT_TEMPLATE" ]; then
    echo -e "${YELLOW}Warning: $CR_PROMPT_TEMPLATE not found. Skipping CR gate.${NC}"
    add_timeline_event "Story ${STORY_KEY}: CR skipped (no template)"
    return 0
  fi

  add_timeline_event "Story ${STORY_KEY}: CR started"
  update_progress_report "Code Review"

  CR_ITERATION=0
  CR_RESULT="CR-FIXED"

  while [ "$CR_RESULT" = "CR-FIXED" ] && [ $CR_ITERATION -lt $MAX_CR_ITERATIONS ]; do
    CR_ITERATION=$((CR_ITERATION + 1))

    echo -e "${BLUE}CR Iteration $CR_ITERATION of $MAX_CR_ITERATIONS${NC}"

    generate_cr_prompt

    cr_output=$(claude -p "$(cat CR-PROMPT.md)" --output-format text --dangerously-skip-permissions 2>&1) || true
    echo "$cr_output"

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

    if [ "$CR_RESULT" = "CR-FIXED" ] && [ $CR_ITERATION -lt $MAX_CR_ITERATIONS ]; then
      echo -e "${YELLOW}Issues were fixed. Re-running CR to verify...${NC}"
      sleep 2
    fi
  done

  rm -f CR-PROMPT.md

  if [ "$CR_RESULT" = "CR-PASS" ]; then
    update_status "in-progress" "done"
    echo -e "${GREEN}Story ${STORY_KEY} CR passed after $CR_ITERATION iteration(s)${NC}"
    add_timeline_event "Story ${STORY_KEY}: CR-PASS, marked done"
    update_progress_report "CR Passed — Story Done"
    return 0
  else
    update_status "in-progress" "review"
    add_timeline_event "Story ${STORY_KEY}: CR-${CR_RESULT}"
    update_progress_report "CR ${CR_RESULT}"
    if [ "$CR_RESULT" = "CR-BLOCKED" ]; then
      echo -e "${YELLOW}CR blocked — human intervention needed.${NC}"
    else
      echo -e "${YELLOW}Max CR iterations reached.${NC}"
    fi
    return 1
  fi
}

# ========================================
# Phase 4: Epic Validation
# ========================================

check_epic_complete() {
  if [ "$SKIP_VALIDATION" = "true" ]; then
    return 0
  fi

  local epic_num=$(echo "$STORY_KEY" | grep -oE '^\d+')
  if [ -z "$epic_num" ]; then return 0; fi

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   Phase 4: Epic $epic_num Check${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  local epic_result=$(node "$SPRINT_STATUS_TOOL" epic-stories "$epic_num" 2>&1)
  local all_done=$(echo "$epic_result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.allDone)")
  local epic_status=$(echo "$epic_result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.epicStatus)")

  if [ "$all_done" != "true" ]; then
    echo -e "${CYAN}Epic $epic_num not yet complete (some stories remaining).${NC}"
    add_timeline_event "Epic $epic_num: not all stories done yet"
    return 0
  fi

  if [ "$epic_status" = "done" ]; then
    echo -e "${GREEN}Epic $epic_num already marked done.${NC}"
    return 0
  fi

  echo -e "${CYAN}All stories in Epic $epic_num are done! Running epic validation...${NC}"
  add_timeline_event "Epic $epic_num: all stories done, validating"
  update_progress_report "Epic $epic_num Validation"

  # Run full build + test
  echo -e "${CYAN}Running full build...${NC}"
  if ! npm run build 2>&1 | tail -20; then
    echo -e "${RED}Build failed during epic validation${NC}"
    add_timeline_event "Epic $epic_num: build FAILED"
    node "$SPRINT_STATUS_TOOL" update-status "epic-${epic_num}" "review" 2>/dev/null || true
    return 0  # Don't block chaining
  fi

  echo -e "${CYAN}Running full test suite...${NC}"
  if ! npx vitest run --reporter=verbose 2>&1 | tail -50; then
    echo -e "${RED}Tests failed during epic validation${NC}"
    add_timeline_event "Epic $epic_num: tests FAILED"
    node "$SPRINT_STATUS_TOOL" update-status "epic-${epic_num}" "review" 2>/dev/null || true
    return 0  # Don't block chaining
  fi

  # Check for epic-specific validation script
  local epic_validation="_bmad-output/implementation-artifacts/epic-${epic_num}-validation.sh"
  if [ -f "$epic_validation" ]; then
    echo -e "${CYAN}Running epic-specific validation...${NC}"
    if ! bash "$epic_validation" 2>&1 | tail -20; then
      echo -e "${RED}Epic validation script failed${NC}"
      add_timeline_event "Epic $epic_num: validation script FAILED"
      node "$SPRINT_STATUS_TOOL" update-status "epic-${epic_num}" "review" 2>/dev/null || true
      return 0
    fi
  fi

  # Mark epic as done
  node "$SPRINT_STATUS_TOOL" update-status "epic-${epic_num}" "done" 2>/dev/null || true
  echo -e "${GREEN}Epic $epic_num validation passed — marked done!${NC}"
  add_timeline_event "Epic $epic_num: DONE"
  update_progress_report "Epic $epic_num Complete"
  return 0
}

# ========================================
# Phase 5: Create Story (CS)
# ========================================

trigger_create_story() {
  if [ "$SKIP_CS" = "true" ]; then
    echo -e "${YELLOW}Skipping auto-CS (RALPH_SKIP_CS=true)${NC}"
    return 1
  fi

  if [ ! -f "$CS_PROMPT_TEMPLATE" ]; then
    echo -e "${YELLOW}Warning: $CS_PROMPT_TEMPLATE not found. Cannot auto-create stories.${NC}"
    return 1
  fi

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   Phase 5: Create Story (CS)${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # Check what needs CS
  local cs_key="${NEEDS_CS_KEY:-}"
  local cs_epic="${NEEDS_CS_EPIC:-}"
  local cs_story="${NEEDS_CS_STORY:-}"

  if [ -z "$cs_key" ]; then
    # Discover next backlog story
    local result=$(node "$SPRINT_STATUS_TOOL" next-story 2>&1)
    local is_done=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.done)")
    local needs_cs=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.needsCS||false)")

    if [ "$is_done" = "true" ]; then
      echo -e "${GREEN}No more stories to create. Sprint complete!${NC}"
      add_timeline_event "All stories complete — sprint done"
      return 1
    fi

    cs_key=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.storyKey)")
    cs_epic=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.epicNum)")
    cs_story=$(echo "$result" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.storyNum)")

    if [ "$needs_cs" != "true" ]; then
      # Story file already exists (ready-for-dev or in-progress) — no CS needed
      NEEDS_CS_KEY=""
      return 0
    fi
  fi

  echo -e "${CYAN}Creating story: $cs_key (Epic $cs_epic, Story $cs_story)${NC}"
  add_timeline_event "CS started for ${cs_key}"
  update_progress_report "Creating Story ${cs_key}"

  generate_cs_prompt "$cs_key" "$cs_epic" "$cs_story"

  local cs_output=$(claude -p "$(cat CS-PROMPT.md)" --output-format text --dangerously-skip-permissions 2>&1) || true
  echo "$cs_output" | tail -30

  rm -f CS-PROMPT.md

  local expected_file="_bmad-output/implementation-artifacts/${cs_key}.md"
  if [ -f "$expected_file" ]; then
    echo -e "${GREEN}✓ Story file created: $expected_file${NC}"
    add_timeline_event "CS completed for ${cs_key}"
    NEEDS_CS_KEY=""
    return 0
  else
    echo -e "${RED}CS failed — story file not created at $expected_file${NC}"
    add_timeline_event "CS FAILED for ${cs_key}"
    return 1
  fi
}

# ========================================
# Main Pipeline
# ========================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Ralph-BMAD Autonomous Pipeline${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Chain mode:         ${GREEN}$CHAIN_MODE${NC}"
echo -e "Max retries/task:   ${GREEN}$MAX_RETRIES${NC}"
echo -e "Max CR iterations:  ${GREEN}$MAX_CR_ITERATIONS${NC}"
echo -e "Wall-clock timeout: ${GREEN}${WALL_CLOCK_TIMEOUT}s ($(( WALL_CLOCK_TIMEOUT / 60 ))m)${NC}"
echo -e "Skip validation:    ${GREEN}$SKIP_VALIDATION${NC}"
echo -e "Skip CS:            ${GREEN}$SKIP_CS${NC}"
if [ -n "$EXPLICIT_STORY" ]; then
  echo -e "Explicit story:     ${GREEN}$EXPLICIT_STORY${NC}"
fi
echo ""

# Initialize progress report
STORY_KEY=""
STORY_FILE=""
NEEDS_CS_KEY=""
NEEDS_CS_EPIC=""
NEEDS_CS_STORY=""
update_progress_report "Starting"

# ========================================
# Outer Chaining Loop
# ========================================

STORIES_COMPLETED=0

while true; do
  check_wall_clock

  # Phase 0: Discover
  DISCOVER_RESULT=0
  discover_next_story || DISCOVER_RESULT=$?

  if [ $DISCOVER_RESULT -eq 1 ]; then
    # All done
    break
  fi

  if [ $DISCOVER_RESULT -eq 2 ]; then
    # Needs CS first
    if ! trigger_create_story; then
      echo -e "${RED}Cannot create story. Stopping.${NC}"
      break
    fi
    # Re-discover after CS
    continue
  fi

  # Validate story file exists
  if [ ! -f "$STORY_FILE" ]; then
    echo -e "${RED}Error: Story file not found: $STORY_FILE${NC}"
    break
  fi

  # Set up persistent log directory
  RUN_TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
  LOG_DIR="ralph-logs/${STORY_KEY}-${RUN_TIMESTAMP}"
  mkdir -p "$LOG_DIR"

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   Story: $STORY_KEY${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo -e "File:     ${GREEN}$STORY_FILE${NC}"
  echo -e "Log dir:  ${GREEN}$LOG_DIR${NC}"
  echo ""

  add_timeline_event "Story ${STORY_KEY} started"
  update_progress_report "Task Execution"

  # Update story status: ready-for-dev → in-progress
  if grep -q "^Status: ready-for-dev" "$STORY_FILE" 2>/dev/null; then
    update_status "ready-for-dev" "in-progress"
    echo -e "${BLUE}Story status: ready-for-dev → in-progress${NC}"
  fi

  # Phase 1: Task Loop
  if ! run_task_loop; then
    update_status "in-progress" "review"
    echo -e "${YELLOW}Story marked REVIEW — task loop failed.${NC}"
    rm -f PROMPT.md
    echo -e "${YELLOW}Run log saved to: $LOG_DIR${NC}"
    if [ "$CHAIN_MODE" != "true" ]; then
      break
    fi
    add_timeline_event "Story ${STORY_KEY}: task loop FAILED, marked review"
    # In chain mode, stop on failure (tasks are sequential, can't skip a story)
    break
  fi

  # Phase 2: Story Validation
  if ! validate_story; then
    update_status "in-progress" "review"
    echo -e "${YELLOW}Story marked REVIEW — validation failed.${NC}"
    rm -f PROMPT.md
    break
  fi

  # Phase 3: CR Gate
  if ! run_cr_gate; then
    rm -f PROMPT.md
    break
  fi

  # Phase 4: Epic Validation
  check_epic_complete

  STORIES_COMPLETED=$((STORIES_COMPLETED + 1))

  # Clean up run log directory
  if [ -d "$LOG_DIR" ]; then
    if [ -s "$LOG_DIR/failure-learnings.md" ]; then
      find "$LOG_DIR" -type f ! -name "failure-learnings.md" -delete 2>/dev/null || true
      echo -e "${DIM}Failure learnings saved to: $LOG_DIR/failure-learnings.md${NC}"
    else
      rm -rf "$LOG_DIR" 2>/dev/null || true
    fi
  fi

  rm -f PROMPT.md

  # Phase 6: Chain decision
  if [ "$CHAIN_MODE" != "true" ]; then
    echo -e "${CYAN}Single-story mode. Stopping after story completion.${NC}"
    break
  fi

  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}   Story complete! Chaining to next...${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""

  # Reset wall-clock timer for next story so each story gets a full budget
  RUN_START=$(date +%s)

  # Phase 5: Create next story if needed
  NEEDS_CS_KEY=""
  # Reset for next discovery cycle
  EXPLICIT_STORY=""

  sleep 3
done

# Final summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Ralph Pipeline Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Stories completed: ${GREEN}$STORIES_COMPLETED${NC}"
echo -e "Total runtime:     ${GREEN}$(( ($(date +%s) - RUN_START) / 60 ))m$(( ($(date +%s) - RUN_START) % 60 ))s${NC}"
echo ""

update_progress_report "Pipeline Complete ($STORIES_COMPLETED stories)"

exit 0
