# Story {{epic_num}}.{{story_num}}: {{story_title}}

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a {{role}},
I want {{action}},
so that {{benefit}}.

## Acceptance Criteria

1. [Add acceptance criteria from epics/PRD]

## Tasks / Subtasks

- [ ] Task 1 (AC: #)
  - [ ] Subtask 1.1
- [ ] Task 2 (AC: #)
  - [ ] Subtask 2.1

## Ralph Tasks JSON

<!-- JSON task manifest for Ralph loop execution. Each task = one fresh-context iteration.
     Keep tasks in sync with Tasks/Subtasks checkboxes above. Only modify "passes" field during execution.
     See ralph-task-guide.md for task decomposition best practices. -->

```json
[
  {
    "id": "task-1",
    "title": "{{task_title}}",
    "acceptanceCriteria": ["AC1"],
    "steps": [
      "{{step_1_with_file_path}}",
      "{{step_2_with_file_path}}"
    ],
    "checkCommands": [
      "{{bash_verification_command_1}}",
      "{{bash_verification_command_2}}"
    ],
    "passes": false
  }
]
```

## Story Validation

<!-- Optional: Commands to validate the entire story works as a whole after all tasks pass.
     Ralph runs these AFTER all tasks complete but BEFORE code review.
     The CS agent should populate this with service-specific test commands. -->

```bash
# Example: run full test suite for the story's primary service
# cd services/<service-name> && npx vitest run
npm run build 2>&1 | tail -20
npx vitest run --reporter=verbose 2>&1 | tail -50
```

## Dev Notes

- Relevant architecture patterns and constraints
- Source tree components to touch
- Testing standards summary

> **Integration Test Integrity Rule:** Integration tests MUST connect to real infrastructure (MCP bridges, databases, APIs) — never use mocks, stubs, or fake servers. Use `describe.skipIf` to gracefully skip when a service is unavailable. If a dependency doesn't exist yet, the integration test should verify **graceful failure and fallback behavior** (e.g., FastPathError → LLM fallback), not simulate the missing system with a mock. A passing integration test with mocked dependencies proves nothing about the real integration.

### Project Structure Notes

- Alignment with unified project structure (paths, modules, naming)
- Detected conflicts or variances (with rationale)

### References

- Cite all technical details with source paths and sections, e.g. [Source: docs/<file>.md#Section]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
