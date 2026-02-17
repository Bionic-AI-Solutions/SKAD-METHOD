---
title: Autonomous Agent Harness Overview
description: Introduction to autonomous agent capabilities in SKAD
---

# Autonomous Agent Harness - Overview

## What is the Autonomous Agent Harness?

The Autonomous Agent Harness integrates Claude's native Task tool with SKAD's workflow execution engine, enabling **truly autonomous development** where specialized AI agents work independently to complete complex tasks.

## Key Capabilities

### 1. Parallel Context Gathering (`create-story`)
Multiple Explore agents work simultaneously to analyze different artifacts:
- **Epic Analyzer**: Extracts complete epic context and story requirements
- **Architecture Analyzer**: Identifies technical constraints and patterns
- **Previous Story Learner**: Extracts learnings from completed work
- **Git Pattern Analyzer**: Discovers code conventions from commit history
- **Library Researcher**: Finds latest versions and best practices

**Result**: Self-sufficient story files with ALL context embedded - no external references needed!

**Performance**: 3-4x faster than sequential analysis (~90 seconds vs 5+ minutes)

### 2. Autonomous Development Loops (`dev-story`)
A single development agent works continuously until 100% complete:
- Reads self-sufficient story file (no external context needed)
- Implements tasks in order using TDD (red-green-refactor)
- Runs tests after every change
- Retries on failures (up to 3 attempts per task)
- Continues in loops until ALL tests pass and ALL ACs met
- Only stops on completion or HALT conditions

**Result**: Zero human intervention during implementation - agent works autonomously!

## Architecture

```
SKAD Workflow Layer
    ↓
workflow.xml (Enhanced with subagent tags)
    ↓
Claude Task Tool
    ↓
Specialized Subagents
  - Explore: Codebase analysis
  - Plan: Implementation strategy
  - Bash: Command execution
  - General: Mixed tasks
```

## Self-Sufficient Story Architecture

**Problem**: Context limits prevent agents from loading everything (epics, architecture, previous stories, etc.)

**Solution**: `create-story` embeds ALL context into story files using parallel agents:
- Epic requirements → Embedded in Dev Notes
- Architecture constraints → Embedded in Dev Notes
- Library versions/APIs → Embedded in Dev Notes
- Previous learnings → Embedded in Dev Notes
- Git patterns → Embedded in Dev Notes

**Result**: Dev agents only need story file + codebase - no context limit issues!

## Benefits

### Speed
- **create-story**: 3-4x faster with parallel agents
- **dev-story**: Continuous execution without human intervention

### Quality
- More comprehensive analysis from specialized agents
- Consistent TDD approach with automatic test validation
- Persistent retry logic ensures robustness

### Autonomy
- No human intervention during implementation
- Agents work in loops until completion
- Self-recovery from failures (up to limits)

### Scalability
- No context limit issues (self-sufficient stories)
- Parallel execution for independent tasks
- Configurable agent limits to manage costs

## Configuration

Configure in `module.yaml`:

```yaml
subagents:
  enabled: true  # Enable autonomous agents
  mode: "smart"  # explicit | smart | autonomous
  parallel_limit: 5  # Max concurrent agents
  timeout_default: 120000  # 2 minutes
  fallback_strategy: "graceful-degradation"
```

## Workflows Enhanced

### ✅ create-story
- **Before**: Sequential manual analysis (5+ minutes)
- **After**: Parallel autonomous agents (~90 seconds)
- **Impact**: Self-sufficient stories, 3-4x faster

### ✅ dev-story
- **Before**: Manual step-by-step implementation
- **After**: Autonomous loop execution
- **Impact**: Zero human intervention, continuous work until complete

### 🔄 quick-dev (Planned)
- Background exploration during planning
- Non-blocking context gathering

## Getting Started

1. **Enable autonomous agents** (already enabled by default in module.yaml)
2. **Run create-story** to create self-sufficient story files
3. **Run dev-story** to autonomously implement stories
4. **Monitor progress** - agents report status and results

## Feature Detection

All autonomous features include graceful fallback:
- If Task tool unavailable → Fall back to manual execution
- If agent fails → Retry or manual fallback
- Workflows continue to work without breaking

## Next Steps

- [Agent Types Guide](./agent-types.md) - When to use each agent type
- [Usage Patterns](./patterns.md) - Common autonomous patterns
- [Troubleshooting](./troubleshooting.md) - Debugging agent issues
