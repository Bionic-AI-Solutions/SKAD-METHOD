#!/usr/bin/env bash
# patch-install-dev-tasks.sh
#
# Patches an existing SKAD-METHOD installation with the dev-tasks workflow.
# Use this when your project already has SKAD installed and you want the
# new [DT] Dev Tasks orchestrator without running a full reinstall.
#
# Usage:
#   bash tools/patch-install-dev-tasks.sh /path/to/your-project
#   bash tools/patch-install-dev-tasks.sh          # defaults to current directory
#
# What this does:
#   1. Copies src/bmm/workflows/4-implementation/dev-tasks/ → {project}/_skad/bmm/workflows/4-implementation/dev-tasks/
#   2. Patches dev.agent.yaml to add the [DT] menu trigger (if not already present)
#   3. Patches create-tasks/task-template.md to add Status comment block (if not already present)
#   4. Patches sprint-status-template.yaml to add current_task documentation (if not already present)
#
# Safe to re-run: all patches are idempotent.

set -euo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_ROOT/src/bmm"

TARGET_PROJECT="${1:-$(pwd)}"
SKAD="$TARGET_PROJECT/_skad/bmm"

# ── Validate ──────────────────────────────────────────────────────────────────

if [ ! -d "$TARGET_PROJECT" ]; then
  echo "❌ Target project directory not found: $TARGET_PROJECT"
  exit 1
fi

if [ ! -d "$SKAD" ]; then
  echo "❌ No _skad/bmm found in: $TARGET_PROJECT"
  echo "   Run 'npx skad-method install --directory $TARGET_PROJECT' first."
  exit 1
fi

echo "🔧 Patching SKAD installation in: $TARGET_PROJECT"
echo "   Source: $SRC"
echo "   Target: $SKAD"
echo ""

# ── Step 1: Copy dev-tasks workflow ───────────────────────────────────────────

DEST_WORKFLOW="$SKAD/workflows/4-implementation/dev-tasks"
mkdir -p "$DEST_WORKFLOW"
cp -f "$SRC/workflows/4-implementation/dev-tasks/workflow.md" "$DEST_WORKFLOW/workflow.md"
cp -f "$SRC/workflows/4-implementation/dev-tasks/skad-skill-manifest.yaml" "$DEST_WORKFLOW/skad-skill-manifest.yaml"
echo "✅ Copied dev-tasks workflow → _skad/bmm/workflows/4-implementation/dev-tasks/"

# ── Step 2: Patch dev.agent.yaml — add [DT] trigger if missing ───────────────

AGENT_FILE="$SKAD/agents/dev.agent.yaml"

if [ ! -f "$AGENT_FILE" ]; then
  echo "⚠️  dev.agent.yaml not found at $AGENT_FILE — skipping agent patch."
else
  if grep -q "dev-tasks" "$AGENT_FILE"; then
    echo "✅ [DT] trigger already present in dev.agent.yaml — skipping."
  else
    # Insert the DT trigger block before the CR trigger line
    DT_BLOCK="
    - trigger: DT or fuzzy match on dev-tasks
      workflow: \"{project-root}/_skad/bmm/workflows/4-implementation/dev-tasks/workflow.md\"
      description: \"[DT] Dev Tasks: Orchestrate task-by-task implementation with automated implement → review → test pipeline, stall detection, and configurable human checkpoints.\"\n"

    # Use awk to insert before the CR trigger line
    awk -v block="$DT_BLOCK" '
      /trigger: CR or fuzzy match on code-review/ { print block }
      { print }
    ' "$AGENT_FILE" > "$AGENT_FILE.tmp" && mv "$AGENT_FILE.tmp" "$AGENT_FILE"

    echo "✅ Added [DT] trigger to dev.agent.yaml"
  fi
fi

# ── Step 3: Patch task-template.md — add Status comment block if missing ──────

TASK_TEMPLATE="$SKAD/workflows/4-implementation/create-tasks/task-template.md"

if [ ! -f "$TASK_TEMPLATE" ]; then
  echo "⚠️  task-template.md not found — skipping."
else
  if grep -q "in-dev-complete" "$TASK_TEMPLATE"; then
    echo "✅ Status comment block already present in task-template.md — skipping."
  else
    # Insert comment block after the **Status:** line using awk
    awk '
      /\*\*Status:\*\* ready-for-task/ {
        print
        print ""
        print "<!-- Status values (managed by dev-tasks orchestrator):"
        print "  ready-for-task  — generated, not yet started"
        print "  in-dev          — Phase 1 (implement) sub-agent running"
        print "  in-dev-complete — implementation done, awaiting review"
        print "  in-review       — Phase 2 (self-review) sub-agent running"
        print "  in-test         — Phase 3 (test) sub-agent running"
        print "  passed          — all 3 phases complete"
        print "  failed          — halted, requires human intervention"
        print "-->"
        next
      }
      { print }
    ' "$TASK_TEMPLATE" > "$TASK_TEMPLATE.tmp" && mv "$TASK_TEMPLATE.tmp" "$TASK_TEMPLATE"

    echo "✅ Added Status comment block to task-template.md"
  fi
fi

# ── Step 4: Patch sprint-status-template.yaml — add current_task docs ─────────

SPRINT_TEMPLATE="$SKAD/workflows/4-implementation/sprint-planning/sprint-status-template.yaml"

if [ ! -f "$SPRINT_TEMPLATE" ]; then
  echo "⚠️  sprint-status-template.yaml not found — skipping."
else
  if grep -q "current_task" "$SPRINT_TEMPLATE"; then
    echo "✅ current_task documentation already present in sprint-status-template.yaml — skipping."
  else
    awk '
      /^#   - in-progress: Developer actively working on implementation/ {
        print
        print "#              Optional inline comment: # current_task: task-N-slug"
        print "#              Added by dev-tasks orchestrator to track resume point after context reset."
        print "#              Example: 1-2-account-management: in-progress  # current_task: task-3-add-jwt-middleware"
        next
      }
      { print }
    ' "$SPRINT_TEMPLATE" > "$SPRINT_TEMPLATE.tmp" && mv "$SPRINT_TEMPLATE.tmp" "$SPRINT_TEMPLATE"

    echo "✅ Added current_task documentation to sprint-status-template.yaml"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "🎉 Patch complete! Dev Tasks workflow is now installed."
echo ""
echo "   Trigger it with:  [DT] dev-tasks"
echo "   Or set autonomy mode in: $TARGET_PROJECT/_skad/bmm/config.yaml"
echo "     autonomy_mode: halt-after-story  # implement-only | halt-after-story | halt-on-high | full-hands-off"
