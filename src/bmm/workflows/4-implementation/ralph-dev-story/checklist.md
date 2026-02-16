# Ralph Dev Story Pre-Launch Checklist

Validate that all prerequisites are met before launching the Ralph loop.

## Story Readiness

- [ ] Story file exists and is accessible
- [ ] Story has `Status: ready-for-dev`
- [ ] Story file has valid `## Ralph Tasks JSON` section (exact header required by extract script)
- [ ] Ralph Tasks JSON is a valid JSON array
- [ ] All ralph tasks have required fields: `id`, `title`, `acceptanceCriteria`, `steps`, `checkCommands`, `passes`
- [ ] Remaining tasks have `"passes": false`
- [ ] Tasks/Subtasks markdown checkboxes are in sync with Ralph Tasks JSON

## PROMPT.md Generation

- [ ] PROMPT.md generated at project root
- [ ] PROMPT.md references the correct story file path via `@` syntax
- [ ] PROMPT.md references `@activity.md`
- [ ] Start command extracted from Dev Notes and included
- [ ] Build/lint/test commands extracted and included
- [ ] Verification instructions appropriate for story type (browser/tests/both)

## Activity Log

- [ ] activity.md initialized at project root
- [ ] activity.md contains story key and date

## Ralph Scripts

- [ ] ralph.sh exists at project root and is executable
- [ ] ralph-bmad.sh exists at project root and is executable

## Context Self-Sufficiency

- [ ] Story Dev Notes contain all architecture and tech stack context
- [ ] Story is fully self-sufficient (no external file references needed)
- [ ] Each ralph task is completable in one fresh-context iteration
