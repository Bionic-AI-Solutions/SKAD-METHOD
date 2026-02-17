#!/bin/bash

# Install Ralph-Enhanced SKAD Method to a target project
# ======================================================
# All assets (scripts, customizations, workflows) live inside SKAD-METHOD/.
# This installer copies everything needed to the target directory so the
# resulting setup is completely self-sufficient.
#
# Usage: ./install-ralph-skad.sh <target-directory>
# Example: ./install-ralph-skad.sh /path/to/my-project
#
# Can also be invoked from the repo root:
#   ./SKAD-METHOD/scripts/install-ralph-skad.sh /path/to/my-project

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Resolve paths relative to this script's location inside SKAD-METHOD/scripts/
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKAD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_DIR="$1"

if [ -z "$TARGET_DIR" ]; then
  echo -e "${RED}Error: Missing required argument${NC}"
  echo ""
  echo "Usage: $0 <target-directory>"
  echo "Example: $0 /path/to/my-project"
  echo ""
  echo "Installs ralph-enhanced SKAD method to the target project."
  echo "Everything is packaged inside SKAD-METHOD/ — this is a self-contained install."
  echo ""
  echo "What gets installed:"
  echo "  - SKAD Method framework (with ralph workflows baked in)"
  echo "  - ralph.sh                       (autonomous loop engine)"
  echo "  - ralph-skad.sh                  (task-level executor + CR gate)"
  echo "  - scripts/ralph-extract-task.js    (task extractor for ralph-skad.sh)"
  echo "  - scripts/ralph-sprint-status.js  (sprint status parser for chaining)"
  echo "  - cr-prompt.template.md           (CR gate prompt template)"
  echo "  - cs-prompt.template.md           (headless CS prompt template)"
  echo "  - Agent customizations            (.customize.yaml files with ralph context)"
  exit 1
fi

# Verify SKAD root looks correct
if [ ! -f "$SKAD_ROOT/tools/cli/skad-cli.js" ]; then
  echo -e "${RED}Error: SKAD CLI not found at $SKAD_ROOT/tools/cli/skad-cli.js${NC}"
  echo "Expected this script to be at SKAD-METHOD/scripts/install-ralph-skad.sh"
  echo "Actual location: $SCRIPT_DIR"
  exit 1
fi

# ─── Step 0: Ensure npm dependencies are installed ───
if [ ! -d "$SKAD_ROOT/node_modules" ]; then
  echo -e "${BLUE}Installing SKAD CLI dependencies...${NC}"
  (cd "$SKAD_ROOT" && npm install --no-fund --no-audit 2>&1) || {
    echo -e "${RED}Error: Failed to install npm dependencies in $SKAD_ROOT${NC}"
    echo "Make sure Node.js >= 20 and npm are available."
    exit 1
  }
  echo -e "  ${GREEN}Dependencies installed${NC}"
  echo ""
fi

# Resolve target directory (create if needed)
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$TARGET_DIR"
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Ralph-Enhanced SKAD Method Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "SKAD Source: ${GREEN}$SKAD_ROOT${NC}"
echo -e "Target:      ${GREEN}$TARGET_DIR${NC}"
echo ""

# ─── Step 1: Run standard SKAD install using our forked source ───
echo -e "${BLUE}Step 1: Installing SKAD Method (with ralph integration)...${NC}"
echo ""
node "$SKAD_ROOT/tools/cli/skad-cli.js" install --directory "$TARGET_DIR" --modules skm --tools claude-code -y

# ─── Step 2: Copy ralph scripts to target project root ───
echo ""
echo -e "${BLUE}Step 2: Installing ralph scripts...${NC}"

if [ -f "$SCRIPT_DIR/ralph.sh" ]; then
  cp "$SCRIPT_DIR/ralph.sh" "$TARGET_DIR/ralph.sh"
  chmod +x "$TARGET_DIR/ralph.sh"
  echo -e "  ${GREEN}Installed: ralph.sh${NC}"
else
  echo -e "  ${RED}Error: ralph.sh not found at $SCRIPT_DIR/ralph.sh${NC}"
  exit 1
fi

if [ -f "$SCRIPT_DIR/ralph-skad.sh" ]; then
  cp "$SCRIPT_DIR/ralph-skad.sh" "$TARGET_DIR/ralph-skad.sh"
  chmod +x "$TARGET_DIR/ralph-skad.sh"
  echo -e "  ${GREEN}Installed: ralph-skad.sh${NC}"
else
  echo -e "  ${RED}Error: ralph-skad.sh not found at $SCRIPT_DIR/ralph-skad.sh${NC}"
  exit 1
fi

if [ -f "$SCRIPT_DIR/cr-prompt.template.md" ]; then
  cp "$SCRIPT_DIR/cr-prompt.template.md" "$TARGET_DIR/cr-prompt.template.md"
  echo -e "  ${GREEN}Installed: cr-prompt.template.md${NC}"
else
  echo -e "  ${YELLOW}Warning: cr-prompt.template.md not found. CR gate will be skipped during ralph-skad.sh runs.${NC}"
fi

if [ -f "$SCRIPT_DIR/ralph-extract-task.js" ]; then
  mkdir -p "$TARGET_DIR/scripts"
  cp "$SCRIPT_DIR/ralph-extract-task.js" "$TARGET_DIR/scripts/ralph-extract-task.js"
  echo -e "  ${GREEN}Installed: scripts/ralph-extract-task.js${NC}"
else
  echo -e "  ${RED}Error: ralph-extract-task.js not found at $SCRIPT_DIR/ralph-extract-task.js${NC}"
  exit 1
fi

if [ -f "$SCRIPT_DIR/ralph-sprint-status.js" ]; then
  mkdir -p "$TARGET_DIR/scripts"
  cp "$SCRIPT_DIR/ralph-sprint-status.js" "$TARGET_DIR/scripts/ralph-sprint-status.js"
  echo -e "  ${GREEN}Installed: scripts/ralph-sprint-status.js${NC}"
else
  echo -e "  ${RED}Error: ralph-sprint-status.js not found at $SCRIPT_DIR/ralph-sprint-status.js${NC}"
  exit 1
fi

if [ -f "$SCRIPT_DIR/cs-prompt.template.md" ]; then
  cp "$SCRIPT_DIR/cs-prompt.template.md" "$TARGET_DIR/cs-prompt.template.md"
  echo -e "  ${GREEN}Installed: cs-prompt.template.md${NC}"
else
  echo -e "  ${YELLOW}Warning: cs-prompt.template.md not found. Headless CS will be unavailable.${NC}"
fi

# ─── Step 3: Copy agent customization files ───
echo ""
echo -e "${BLUE}Step 3: Installing agent customization files...${NC}"

CUSTOMIZATIONS_SRC="$SKAD_ROOT/customizations/agents"
AGENT_CONFIG_DIR="$TARGET_DIR/_skad/_config/agents"

if [ -d "$AGENT_CONFIG_DIR" ] && [ -d "$CUSTOMIZATIONS_SRC" ]; then
  for f in "$CUSTOMIZATIONS_SRC"/*.customize.yaml; do
    if [ -f "$f" ]; then
      BASENAME=$(basename "$f")
      cp "$f" "$AGENT_CONFIG_DIR/"
      echo -e "  ${GREEN}Installed: $BASENAME${NC}"
    fi
  done
else
  if [ ! -d "$AGENT_CONFIG_DIR" ]; then
    echo -e "  ${YELLOW}Warning: Agent config directory not found at $AGENT_CONFIG_DIR${NC}"
    echo -e "  ${YELLOW}SKAD install may not have completed. Customizations skipped.${NC}"
  fi
  if [ ! -d "$CUSTOMIZATIONS_SRC" ]; then
    echo -e "  ${YELLOW}Warning: Customizations source not found at $CUSTOMIZATIONS_SRC${NC}"
  fi
fi

# ─── Step 4: Recompile agents to apply customizations ───
echo ""
echo -e "${BLUE}Step 4: Recompiling agents with customizations...${NC}"
node "$SKAD_ROOT/tools/cli/skad-cli.js" install --directory "$TARGET_DIR" --action compile-agents

# ─── Done ───
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Ralph-enhanced SKAD Method installed at: $TARGET_DIR"
echo ""
echo -e "${BLUE}Installed files:${NC}"
echo "  _skad/                           SKAD framework (with ralph workflows)"
echo "  _skad/_config/agents/            Agent customizations (ralph context)"
echo "  ralph.sh                         Ralph loop engine (fresh context per iteration)"
echo "  ralph-skad.sh                    SKAD autonomous pipeline (7-phase chaining)"
echo "  scripts/ralph-extract-task.js    Task extractor for ralph-skad.sh"
echo "  scripts/ralph-sprint-status.js   Sprint status parser for discovery + chaining"
echo "  cr-prompt.template.md            CR gate prompt template (adversarial review)"
echo "  cs-prompt.template.md            Headless CS prompt template (auto story creation)"
echo ""
echo -e "${BLUE}Workflow Progression:${NC}"
echo "  Phase 1-3: Analysis → Planning → Solutioning (unchanged)"
echo "  Phase 4:   CS → DS → CR"
echo ""
echo "  CS  = Create Story (includes Ralph Tasks JSON)"
echo "  DS  = Dev Story     DEFAULT: Ralph loop (fresh context per task) + auto CR gate"
echo "  DSC = Dev Story Classic      fallback: original subagent"
echo "  CR  = Code Review   (unchanged)"
echo "  QA  = QA Automate   DEFAULT: Ralph loop (one feature per iteration)"
echo "  QAC = QA Classic             fallback: original subagent"
echo "  RUX = Ralph UX Story         UX implementation via Ralph"
echo ""
echo -e "${YELLOW}Quick start:${NC}"
echo "  1. Load SM agent  → run CS (Create Story)"
echo "  2. Load Dev agent → run DS (Ralph Dev Story)"
echo "  3. Load Dev agent → run CR (Code Review)"
echo ""
