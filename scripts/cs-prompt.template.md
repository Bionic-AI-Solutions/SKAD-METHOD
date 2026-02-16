@_bmad/bmm/workflows/4-implementation/create-story/instructions.xml
@_bmad-output/implementation-artifacts/sprint-status.yaml
@_bmad-output/planning-artifacts/epics.md @activity.md

You are performing AUTOMATED Create Story (CS) for the next backlog story.

This is a HEADLESS execution — you make all decisions autonomously. There is no human to ask.

## Target

- Story key: {{story_key}}
- Epic: {{epic_num}}
- Story number: {{story_num}}
- Output file: _bmad-output/implementation-artifacts/{{story_key}}.md

## Instructions

Follow the create-story workflow instructions loaded above (instructions.xml).

1. Read the epics file to extract full context for Epic {{epic_num}}, Story {{story_num}}
2. Read the architecture docs in `_bmad-output/planning-artifacts/` for technical context
3. Analyze previous stories in this epic (check `_bmad-output/implementation-artifacts/{{epic_num}}-*`) for learnings and patterns
4. Create a comprehensive, self-sufficient story file at the output path above
5. Follow the template at `_bmad/bmm/workflows/4-implementation/create-story/template.md`

## Critical Requirements

- The story file must be 100% self-sufficient — embed ALL context the dev agent needs
- Include a `## Story Validation` section with commands to validate the full story after all tasks pass
- Ralph Tasks JSON must follow the schema: id, title, acceptanceCriteria, steps, checkCommands, passes
- Each task should be atomic (~3-5 min, 1-3 files) with specific file paths in steps
- checkCommands must include build, test, and content verification commands
- All tasks start with `"passes": false`

## Integration Test Integrity

> Integration tests MUST connect to real infrastructure (MCP bridges, databases, APIs) — never use mocks, stubs, or fake servers. Use `describe.skipIf` to gracefully skip when a service is unavailable. If a dependency doesn't exist yet, the integration test should verify graceful failure and fallback behavior, not simulate the missing system with a mock.

## Sprint Status Update

After creating the story file:
1. Update sprint-status.yaml: `{{story_key}}: backlog` → `{{story_key}}: ready-for-dev`
2. If this is the first story in Epic {{epic_num}} and epic status is `backlog`, update to `in-progress`

## Commit

```
git add -A && git commit -m "story({{story_key}}): create story file via automated CS"
```

## Completion

When done, output:

<cs-signal>CS-DONE</cs-signal>

If you cannot create the story (missing epics, missing architecture docs, ambiguous requirements), output:

<cs-signal>CS-BLOCKED</cs-signal>
