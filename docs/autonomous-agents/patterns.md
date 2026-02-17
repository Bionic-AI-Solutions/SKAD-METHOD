---
title: Autonomous Agent Patterns
description: Common patterns and best practices for using autonomous agents
---

# Autonomous Agent Patterns

Common patterns for using autonomous agents effectively in SKAD workflows.

## Pattern 1: Parallel Context Gathering

**Use Case**: Need to analyze multiple independent artifacts simultaneously

**Example** (from create-story):
```xml
<invoke-parallel>
  <subagent id="epic-analyzer" type="explore">
    <objective>Extract epic context and requirements</objective>
    <context>{epics_content}</context>
    <output-var>{epic_intelligence}</output-var>
  </subagent>

  <subagent id="arch-analyzer" type="explore">
    <objective>Extract architecture constraints</objective>
    <context>{architecture_content}</context>
    <output-var>{arch_intelligence}</output-var>
  </subagent>

  <subagent id="git-analyzer" type="bash">
    <objective>Analyze last 5 commits for patterns</objective>
    <output-var>{git_intelligence}</output-var>
  </subagent>

  <sync-point>Wait for all agents</sync-point>
</invoke-parallel>

<!-- All results now available -->
<action>Synthesize findings from:
  - {epic_intelligence}
  - {arch_intelligence}
  - {git_intelligence}
</action>
```

**Benefits**:
- 3-4x faster than sequential
- Independent agents work simultaneously
- Comprehensive context gathered quickly

**When to Use**:
- Artifacts are independent
- No shared state needed
- Speed is important

---

## Pattern 2: Autonomous Development Loop

**Use Case**: Implement complete story autonomously without human intervention

**Example** (from dev-story):
```xml
<invoke-subagent type="general" mode="blocking">
  <objective>
    Autonomously implement story to 100% completion:
    - Read self-sufficient story file
    - Implement ALL tasks using TDD
    - Run tests continuously until ALL pass
    - Continue in loops until COMPLETE
  </objective>
  <context>
    <story-file>{story_file}</story-file>
    <project-root>{project_root}</project-root>
  </context>
  <constraints>
    <max-turns>100</max-turns>
    <halt-on>3 consecutive failures, missing dependencies</halt-on>
  </constraints>
  <output-var>{dev_results}</output-var>
</invoke-subagent>

<!-- Handle results -->
<check if="{dev_results}.status == 'completed'">
  <output>✅ Story completed autonomously!</output>
</check>
```

**Benefits**:
- Zero human intervention
- Continuous work until complete
- Self-recovery from failures

**When to Use**:
- Story is self-sufficient (all context embedded)
- Requirements are clear
- Tests can validate correctness

---

## Pattern 3: Feature Detection with Graceful Fallback

**Use Case**: Use autonomous agents when available, fall back to manual when not

**Example**:
```xml
<check if="{task_tool_available} AND {subagents.enabled}">
  <!-- Use autonomous agents -->
  <invoke-parallel>
    <subagent id="analyzer" type="explore">...</subagent>
  </invoke-parallel>
</check>
<else>
  <!-- Fallback to manual execution -->
  <action>Manual sequential analysis</action>
</else>
```

**Benefits**:
- Workflows work in all environments
- Automatic optimization when possible
- No breaking changes

**When to Use**:
- Always! Every workflow should have fallback

---

## Pattern 4: Background Research During Planning

**Use Case**: Gather information non-blockingly while other work happens

**Example**:
```xml
<!-- Spawn background agent -->
<invoke-subagent type="general" mode="background" id="library-research">
  <objective>Research latest React 18 best practices</objective>
  <output-var>{react_research}</output-var>
</invoke-subagent>

<!-- Continue with other work -->
<action>Discuss implementation approach with user</action>
<action>Draft initial plan</action>

<!-- Wait for research to complete -->
<sync-point for="library-research" />

<!-- Now incorporate research into plan -->
<action>Update plan with {react_research} findings</action>
```

**Benefits**:
- Zero perceived wait time
- Parallel work streams
- More efficient use of time

**When to Use**:
- Research not immediately needed
- User interaction happening
- Independent analysis tasks

---

## Pattern 5: Conditional Agent Spawning

**Use Case**: Spawn agents only when specific conditions met

**Example**:
```xml
<invoke-parallel>
  <!-- Always analyze epic -->
  <subagent id="epic-analyzer" type="explore">...</subagent>

  <!-- Only analyze previous story if not first -->
  <check if="story_num > 1">
    <subagent id="prev-story-learner" type="explore">
      <objective>Extract learnings from previous story</objective>
      <output-var>{previous_intelligence}</output-var>
    </subagent>
  </check>

  <!-- Only analyze git if repository exists -->
  <check if="git repository detected">
    <subagent id="git-analyzer" type="bash">
      <objective>Analyze commit history</objective>
      <output-var>{git_intelligence}</output-var>
    </subagent>
  </check>
</invoke-parallel>
```

**Benefits**:
- Efficient resource usage
- Avoid unnecessary work
- Contextual adaptation

---

## Pattern 6: Result Validation and Error Handling

**Use Case**: Safely handle agent failures and validate results

**Example**:
```xml
<invoke-subagent type="explore">
  <objective>Analyze architecture</objective>
  <output-var>{arch_result}</output-var>
</invoke-subagent>

<!-- Validate result before using -->
<check if="{arch_result}.status == 'completed'">
  <action>Use {arch_result}.findings in story</action>
</check>

<check if="{arch_result}.status == 'failed'">
  <output>⚠️ Architecture analysis failed: {arch_result}.error</output>
  <!-- Fallback action -->
  <action>Load architecture manually</action>
</check>

<check if="{arch_result}.status == 'timeout'">
  <output>⏱️ Analysis timed out, using partial results</output>
  <action>Use {arch_result}.partial_findings if available</action>
</check>
```

**Benefits**:
- Robust error handling
- Graceful degradation
- Better user experience

**When to Use**:
- Always validate results
- Provide fallbacks
- Handle edge cases

---

## Pattern 7: Self-Sufficient Context Embedding

**Use Case**: Embed all agent findings into single file for future autonomous use

**Example** (from create-story Step 3):
```xml
<!-- Gather context from parallel agents -->
<invoke-parallel>
  <subagent id="epic-analyzer">...</subagent>
  <subagent id="arch-analyzer">...</subagent>
  <sync-point/>
</invoke-parallel>

<!-- Embed ALL findings in story file -->
<template-output file="{story_file}">
  ## Dev Notes

  ### Epic Context (from {epic_intelligence})
  {epic_intelligence}.findings
  - Epic objectives: ...
  - Related stories: ...
  - Dependencies: ...

  ### Architecture Requirements (from {arch_intelligence})
  {arch_intelligence}.findings
  - Technical stack: ...
  - Patterns: ...
  - Testing standards: ...

  ### Implementation Guidance
  All context needed for autonomous development embedded above.
  NO external file references required!
</template-output>
```

**Benefits**:
- No context limit issues
- Self-contained specifications
- Autonomous development ready

**When to Use**:
- Creating specifications for later autonomous execution
- Preventing context limit problems
- Enabling true autonomy

---

## Pattern 8: Multi-Phase Agent Orchestration

**Use Case**: Complex workflows requiring multiple agent phases

**Example**:
```xml
<!-- Phase 1: Discovery -->
<invoke-subagent type="explore">
  <objective>Find all authentication files</objective>
  <output-var>{auth_files}</output-var>
</invoke-subagent>

<!-- Phase 2: Planning (uses Phase 1 results) -->
<invoke-subagent type="plan">
  <objective>Design refactoring approach for {auth_files}</objective>
  <context>{auth_files}</context>
  <output-var>{refactor_plan}</output-var>
</invoke-subagent>

<!-- Phase 3: Execution (uses Phase 2 results) -->
<invoke-subagent type="general">
  <objective>Execute {refactor_plan} autonomously</objective>
  <context>{refactor_plan}</context>
  <output-var>{execution_result}</output-var>
</invoke-subagent>
```

**Benefits**:
- Complex task decomposition
- Each phase builds on previous
- Structured autonomous execution

**When to Use**:
- Multi-step complex tasks
- Sequential dependencies
- Phased execution needed

---

## Anti-Patterns to Avoid

### ❌ Overloading Context
```xml
<!-- BAD: Too much context -->
<subagent type="explore">
  <context>
    <include>{all_epics}</include>
    <include>{all_architecture}</include>
    <include>{all_stories}</include>
    <include>{git_history_100_commits}</include>
  </context>
</subagent>
```

**Problem**: Context limits, slow execution, high cost

**Solution**: Provide only relevant context

### ❌ Using Wrong Agent Type
```xml
<!-- BAD: Using General for simple search -->
<subagent type="general">
  <objective>Find all .ts files</objective>
</subagent>
```

**Problem**: Unnecessary cost, slower execution

**Solution**: Use Explore for read-only tasks

### ❌ No Error Handling
```xml
<!-- BAD: Assuming success -->
<invoke-subagent type="explore">...</invoke-subagent>
<action>Use {result}.findings</action>  <!-- What if failed? -->
```

**Problem**: Workflow breaks on failures

**Solution**: Always check status

### ❌ Sequential When Parallel Possible
```xml
<!-- BAD: Sequential independent tasks -->
<invoke-subagent id="epic">...</invoke-subagent>
<invoke-subagent id="arch">...</invoke-subagent>
```

**Problem**: Slow, 2x execution time

**Solution**: Use invoke-parallel

---

## Best Practices Summary

1. **Use Parallel When Possible**: Independent tasks → parallel execution
2. **Choose Right Agent Type**: Match capability to task needs
3. **Validate Results**: Always check status before using
4. **Provide Clear Objectives**: Specific is better than vague
5. **Embed Context for Autonomy**: Self-sufficient specs prevent limits
6. **Feature Detect + Fallback**: Works everywhere
7. **Handle Errors Gracefully**: Robust workflows
8. **Use Background Mode**: Non-blocking when appropriate
