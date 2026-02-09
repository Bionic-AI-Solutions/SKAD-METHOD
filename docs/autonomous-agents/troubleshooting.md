---
title: Autonomous Agents Troubleshooting
description: Common issues and solutions for autonomous agents
---

# Autonomous Agents - Troubleshooting

Common issues and solutions when working with autonomous agents.

## Agent Failures

### Issue: Agent Fails to Spawn

**Symptoms**:
- Workflow halts with "Task tool unavailable" message
- Subagent invocation fails

**Causes**:
1. Task tool not available in environment
2. Subagents disabled in configuration
3. Network issues

**Solutions**:
```yaml
# Check configuration
subagents:
  enabled: true  # Must be true
```

If Task tool truly unavailable, workflows should gracefully fall back to manual execution. Check for feature detection:
```xml
<check if="{task_tool_available}">
  <invoke-subagent>...</invoke-subagent>
</check>
<else>
  <!-- Fallback to manual -->
</else>
```

---

### Issue: Agent Times Out

**Symptoms**:
- Agent runs for 2+ minutes then returns timeout status
- Partial results available

**Causes**:
1. Task too complex for time limit
2. Codebase too large to explore
3. Network latency

**Solutions**:

1. **Increase Timeout**:
```yaml
subagents:
  timeout_default: 180000  # 3 minutes instead of 2
```

2. **Break Down Task**:
```xml
<!-- Instead of one large task -->
<subagent type="explore">
  <objective>Analyze entire codebase</objective>
</subagent>

<!-- Break into smaller tasks -->
<invoke-parallel>
  <subagent type="explore">
    <objective>Analyze authentication files only</objective>
    <constraints><max-files>10</max-files></constraints>
  </subagent>
  <subagent type="explore">
    <objective>Analyze API files only</objective>
    <constraints><max-files>10</max-files></constraints>
  </subagent>
</invoke-parallel>
```

3. **Provide More Specific Context**:
```xml
<!-- Better: Targeted context -->
<subagent type="explore">
  <context>
    <include>{specific_epic_content}</include>
    <filter>authentication</filter>
  </context>
</subagent>
```

---

### Issue: Agent Returns Incomplete Results

**Symptoms**:
- Agent completes but findings are sparse
- Missing expected information

**Causes**:
1. Objective not clear enough
2. Context insufficient
3. Wrong agent type

**Solutions**:

1. **Be More Specific**:
```xml
<!-- Vague -->
<objective>Analyze architecture</objective>

<!-- Specific -->
<objective>
  Extract from architecture document:
  - Technical stack with versions
  - Testing frameworks and standards
  - API patterns and conventions
  - Security requirements
  Provide complete findings for each.
</objective>
```

2. **Provide Sufficient Context**:
```xml
<subagent type="explore">
  <objective>Find authentication patterns</objective>
  <context>
    <include>{architecture_content}</include>
    <include>{epics_content}</include>  <!-- Added -->
    <search-terms>authentication, auth, login</search-terms>
  </context>
</subagent>
```

3. **Use Right Agent Type**:
```xml
<!-- Wrong: Explore can't research web -->
<subagent type="explore">
  <objective>Find latest React version</objective>
</subagent>

<!-- Right: General has WebSearch -->
<subagent type="general">
  <objective>Research latest React version using WebSearch</objective>
</subagent>
```

---

## Autonomous Development Issues

### Issue: Dev Agent Halts Prematurely

**Symptoms**:
- dev-story agent stops before completing all tasks
- Returns "halted" status

**Common Causes & Solutions**:

**1. Ambiguous Requirements**:
```
HALT: Task 3 is ambiguous - cannot determine implementation approach
```
**Solution**: Update story file with clearer task description and Dev Notes

**2. Missing Dependencies**:
```
HALT: Required library 'express' not in story Dev Notes
```
**Solution**: Add dependency information to story's Dev Notes

**3. Test Failures After 3 Attempts**:
```
HALT: Tests failing after 3 consecutive attempts on Task 2
```
**Solution**: Review test requirements in story, may need human debugging

**4. Cannot Determine Test Framework**:
```
HALT: Unable to determine how to run tests
```
**Solution**: Add test framework info to story Dev Notes:
```markdown
## Dev Notes
### Testing Standards
- Framework: Jest
- Command: npm test
- Location: tests/ directory
```

---

### Issue: Dev Agent Implements Wrong Approach

**Symptoms**:
- Agent completes but implementation doesn't match expectations
- Tests pass but approach is not desired

**Causes**:
1. Insufficient architecture guidance in story
2. Dev Notes don't specify required patterns

**Solutions**:

1. **Enhance Story Dev Notes**:
```markdown
## Dev Notes

### Architecture Requirements
- MUST use existing AuthService class
- MUST follow repository pattern
- DO NOT create new database connections

### Implementation Approach
- Extend BaseRepository
- Use dependency injection
- Follow error handling pattern from UserService
```

2. **Provide Code Examples in Story**:
```markdown
### Code Patterns to Follow

Example from existing UserService:
```typescript
class UserService extends BaseService {
  constructor(private repository: UserRepository) {}
}
```

Follow this exact pattern for AuthService.
```

---

### Issue: Dev Agent Doesn't Update Story File Correctly

**Symptoms**:
- Tasks not marked complete with [x]
- File List not updated
- Dev Agent Record empty

**Causes**:
1. Agent doesn't have write access to story file
2. Story file path incorrect

**Solutions**:

1. **Verify File Paths**:
```xml
<invoke-subagent type="general">
  <context>
    <story-file>{{story_file}}</story-file>  <!-- Full path -->
    <project-root>{{project_root}}</project-root>
  </context>
</invoke-subagent>
```

2. **Check Agent Output**:
```xml
<check if="{dev_results}.files_modified">
  <!-- Agent did update files -->
</check>
<else>
  <!-- Agent didn't update - check logs -->
  <output>{dev_results}.errors</output>
</else>
```

---

## Context and Performance Issues

### Issue: Context Limit Exceeded

**Symptoms**:
- Error about context size
- Agent unable to load all necessary files

**Causes**:
1. Story file references external documents
2. Too much content passed to agent
3. Story not self-sufficient

**Solutions**:

**Use Self-Sufficient Stories**:
```markdown
<!-- BAD: External references -->
## Dev Notes
See architecture.md for technical stack.
See epics.md for requirements.

<!-- GOOD: Embedded context -->
## Dev Notes

### Technical Stack (from architecture.md)
- Node.js 18.x
- Express 4.18.x
- PostgreSQL 14

### Requirements (from epic 1)
- User must be able to login
- Support OAuth and email/password
```

**Agent Only Needs**:
- Story file (self-sufficient)
- Project root location
- Nothing else!

---

### Issue: Parallel Agents Causing High Costs

**Symptoms**:
- Unexpected API costs
- Many agents spawned simultaneously

**Causes**:
1. Too many parallel agents
2. Wrong agent types (using General when Explore would work)

**Solutions**:

1. **Limit Parallel Agents**:
```yaml
subagents:
  parallel_limit: 3  # Reduce from 5
```

2. **Use Cheaper Agent Types**:
```xml
<!-- Expensive: General -->
<subagent type="general">
  <objective>Read architecture file</objective>
</subagent>

<!-- Cheaper: Explore -->
<subagent type="explore">
  <objective>Read architecture file</objective>
</subagent>
```

3. **Batch Independent Analyses**:
```xml
<!-- Instead of 5 separate agents -->
<subagent type="explore">
  <objective>
    Analyze in one pass:
    - Epic requirements
    - Architecture patterns
    - Previous story learnings
    Provide findings for each area.
  </objective>
</subagent>
```

---

## Configuration Issues

### Issue: Autonomous Mode Not Activating

**Symptoms**:
- Workflows use manual execution
- No agents spawned

**Check Configuration**:
```yaml
# In module.yaml
subagents:
  enabled: true  # ← Must be true
  mode: "smart"  # ← Or "autonomous"
```

**Check Feature Detection**:
- Workflows should detect {task_tool_available}
- If false, check Claude Code environment

---

### Issue: Agents Don't Respect Halt Conditions

**Symptoms**:
- Agent continues despite failures
- Doesn't stop when expected

**Solution - Be Explicit in Constraints**:
```xml
<invoke-subagent type="general">
  <constraints>
    <max-turns>100</max-turns>
    <halt-conditions>
      - 3 consecutive implementation failures on same task
      - Missing dependencies not in story Dev Notes
      - Ambiguous requirements in story file
      - Tests failing after all retry attempts
    </halt-conditions>
  </constraints>
</invoke-subagent>
```

---

## Debugging Tools

### Enable Detailed Logging

Add to workflow for debugging:
```xml
<output>🔍 Debug Info:</output>
<output>- Task tool available: {task_tool_available}</output>
<output>- Subagents enabled: {subagents.enabled}</output>
<output>- Subagent mode: {subagents.mode}</output>
<output>- Agent result status: {agent_result}.status</output>
<output>- Agent errors: {agent_result}.errors</output>
```

### Review Agent Objectives

Before spawning, output the objective:
```xml
<output>Spawning agent with objective:</output>
<output>{objective_text}</output>
<invoke-subagent>
  <objective>{objective_text}</objective>
</invoke-subagent>
```

### Check Result Structure

After agent completes:
```xml
<output>Agent Result:</output>
<output>- Status: {result}.status</output>
<output>- Output length: {result}.output.length</output>
<output>- Findings count: {result}.findings.length</output>
<output>- Errors: {result}.errors</output>
```

---

## Common Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| "Task tool unavailable" | Task tool not accessible | Check environment, use fallback |
| "Agent timeout after 120s" | Agent exceeded time limit | Increase timeout or reduce scope |
| "Context limit exceeded" | Too much content | Use self-sufficient stories, reduce context |
| "Ambiguous requirements" | Task unclear | Improve story Dev Notes |
| "3 consecutive failures" | Implementation stuck | Human debugging needed |
| "Missing dependencies" | Dependency not in story | Add to Dev Notes |

---

## Getting Help

If issues persist:

1. Check this troubleshooting guide
2. Review [agent-types.md](./agent-types.md) for correct usage
3. Review [patterns.md](./patterns.md) for best practices
4. Check story file is self-sufficient (no external references)
5. Verify configuration in module.yaml
6. Review agent objectives for clarity

Still stuck? File an issue with:
- Workflow name
- Agent type used
- Objective text
- Error message
- Result status and errors
