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

## Ralph Tasks

<!-- JSON task manifest for Ralph loop execution. Each task = one fresh-context iteration.
     Keep in sync with Tasks/Subtasks checkboxes above. Only modify "passes" field during execution. -->

```json
[
  {
    "id": "task-1",
    "category": "{{category}}",
    "description": "{{task_description}}",
    "acceptance_criteria": ["AC: #1"],
    "steps": [
      "{{step_1}}",
      "{{step_2}}"
    ],
    "verification": "{{how_to_verify}}",
    "passes": false
  }
]
```

## Dev Notes

- Relevant architecture patterns and constraints
- Source tree components to touch
- Testing standards summary

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
