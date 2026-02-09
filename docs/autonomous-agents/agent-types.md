---
title: Autonomous Agent Types
description: Guide to choosing the right agent type for your task
---

# Autonomous Agent Types

Claude's Task tool provides four specialized subagent types, each optimized for specific tasks.

## Agent Type Reference

### Explore Agent

**Best For:**
- Codebase analysis and pattern discovery
- Searching for existing implementations
- Understanding project structure
- Finding relevant files and code

**Capabilities:**
- Full access to Glob, Grep, Read tools
- Can search codebase efficiently
- Excellent at discovering patterns
- Fast and cost-effective

**When to Use:**
- Epic/architecture analysis in create-story
- Previous story learnings extraction
- Finding similar implementations
- Discovering code conventions

**Example (from create-story):**
```xml
<subagent id="epic-analyzer" type="explore">
  <objective>
    Analyze Epic 1 from epics content and extract complete context,
    requirements, and dependencies
  </objective>
  <context>
    <include>{epics_content}</include>
  </context>
  <output-var>{epic_intelligence}</output-var>
</subagent>
```

### Plan Agent

**Best For:**
- Designing implementation strategies
- Breaking down complex tasks
- Architectural decision-making
- Considering trade-offs

**Capabilities:**
- Full context access
- Strategic thinking
- Can explore codebase
- Implementation planning

**When to Use:**
- Complex task implementation planning
- Choosing between approaches
- Architectural design
- Multi-step strategy development

**Example:**
```xml
<subagent type="plan">
  <objective>
    Design implementation approach for authentication system:
    - Break down into sub-steps
    - Identify files to modify
    - Determine test strategy
  </objective>
  <context>
    <include>{story_context}</include>
  </context>
  <output-var>{implementation_plan}</output-var>
</subagent>
```

### Bash Agent

**Best For:**
- Running commands
- Git operations
- Test execution
- File system operations

**Capabilities:**
- Execute bash commands
- Git analysis
- Test running
- Build operations

**When to Use:**
- Git commit history analysis
- Running test suites
- Build validation
- CLI tool execution

**Example (from create-story):**
```xml
<subagent id="git-analyzer" type="bash">
  <objective>
    Analyze last 5 commits for patterns:
    - Run: git log -5 --name-status
    - Extract code conventions and dependencies
  </objective>
  <output-var>{git_intelligence}</output-var>
</subagent>
```

### General Agent

**Best For:**
- Mixed tasks requiring multiple tools
- Web research
- Complex analysis
- Autonomous development loops

**Capabilities:**
- Full tool access (Read, Write, Edit, Grep, Glob, Bash, WebSearch)
- Can implement code
- Can run tests
- Most flexible but higher cost

**When to Use:**
- Autonomous dev-story implementation
- Library/framework research
- Tasks requiring multiple tool types
- Full implementation cycles

**Example (from dev-story):**
```xml
<subagent type="general" mode="blocking">
  <objective>
    Autonomously implement story to 100% completion:
    - Read self-sufficient story file
    - Implement ALL tasks using TDD
    - Run tests until ALL pass
    - Validate ALL acceptance criteria
  </objective>
  <context>
    <story-file>{story_file}</story-file>
    <project-root>{project_root}</project-root>
  </context>
  <constraints>
    <max-turns>100</max-turns>
  </constraints>
  <output-var>{dev_results}</output-var>
</subagent>
```

## Choosing the Right Agent Type

| Task | Best Agent Type | Why |
|------|----------------|-----|
| Find files matching pattern | **Explore** | Fast, cost-effective |
| Analyze architecture doc | **Explore** | Read + analysis, no writes needed |
| Design implementation | **Plan** | Strategic thinking |
| Run git commands | **Bash** | Command execution |
| Research library versions | **General** | Needs WebSearch |
| Autonomous implementation | **General** | Needs Read, Write, Edit, Bash |
| Extract epic requirements | **Explore** | Read + analysis |
| Previous story learnings | **Explore** | Pattern discovery |

## Cost Considerations

**Most Expensive → Least Expensive:**
1. **General**: Full tool access, most capable, highest cost
2. **Plan**: Strategic thinking, moderate cost
3. **Bash**: Command execution, lower cost
4. **Explore**: Read-only exploration, lowest cost

**Best Practice**: Use the most specialized agent type that can handle your task:
- Don't use General when Explore would suffice
- Don't use Plan for simple analysis
- Do use General for autonomous implementation (worth the cost)

## Parallel vs. Sequential

**Parallel (use invoke-parallel):**
- Tasks are independent
- No shared state
- Can run simultaneously
- Example: Epic + Architecture + Git analysis

**Sequential (use multiple invoke-subagent):**
- Tasks depend on each other
- Later tasks need results from earlier ones
- Must run in order
- Example: Research → Plan → Implement

## Result Structure

All agents return results with this structure:

```javascript
{
  status: "completed" | "failed" | "timeout",
  output: "Main result content",
  findings: [...],  // For Explore agents
  errors: [...],    // If any issues
  metadata: {...}   // Agent-specific data
}
```

Access results via variable:
```xml
{agent_intelligence}.output
{agent_intelligence}.status
{agent_intelligence}.findings
```

## Best Practices

1. **Clear Objectives**: Be specific about what you want
2. **Sufficient Context**: Provide what's needed, not everything
3. **Appropriate Type**: Choose the right agent for the task
4. **Handle Failures**: Check status before using results
5. **Parallel When Possible**: Speed up independent tasks
