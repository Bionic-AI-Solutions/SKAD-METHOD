@test-plan.md @activity.md

You are generating tests for the project using the Ralph Wiggum autonomous loop.
Each iteration you generate tests for exactly ONE feature/component.

First read activity.md to see what was recently accomplished.

## Context

The test-plan.md contains:
- Detected test framework and configuration
- Feature inventory with test type categories
- Ralph Tasks JSON with your task list

## Work on Tasks

Open test-plan.md and find the `## Ralph Tasks` JSON section.
Find the FIRST task where `"passes": false`.

Work on exactly ONE task:
1. Read the task description and target feature
2. Analyze the feature's source code thoroughly
3. Write comprehensive tests using the detected framework: {{test_framework}}
4. Cover:
   - Happy path scenarios
   - Critical edge cases
   - Error handling paths
   - Boundary conditions
5. Run the tests: {{test_command}}
6. Ensure ALL new tests pass on first run

## Log Progress

Append a dated entry to activity.md:
- Feature/component tested
- Test files created (with paths)
- Number of test cases written
- Test results (all passing / any failures)
- Any issues encountered

## Update Task Status

When all new tests pass:
1. In the Ralph Tasks JSON, set this task's `"passes"` field from `false` to `true`
2. Mark the corresponding checkbox `[x]` in the Tasks/Subtasks section
3. Do NOT reformat the JSON array -- only change the `passes` field

## Commit Changes

Make one git commit for the tests:
```
git add -A
git commit -m "test: add tests for [feature/component name]"
```

Do NOT run `git init`, change git remotes, or push.

## Important Rules

- Generate tests for a SINGLE feature per iteration
- Always run tests before marking a task as passing
- Tests must ACTUALLY pass -- never lie about test results
- Use standard test framework APIs only (no custom utilities)
- Follow existing test patterns and conventions in the codebase
- Keep tests simple, readable, and maintainable

## Completion

When ALL tasks in the Ralph Tasks JSON have `"passes": true`, output:

<promise>COMPLETE</promise>
