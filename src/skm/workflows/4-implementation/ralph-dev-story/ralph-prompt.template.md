@{{story_file_path}} @activity.md

You are implementing SKAD story {{story_key}} using the Ralph Wiggum autonomous loop.
Each iteration you work on exactly ONE task. Read the full story file for ALL context.

First read activity.md to see what was recently accomplished.

## Context

The story file contains ALL context you need:
- Story requirements and acceptance criteria
- Dev Notes with architecture patterns, tech stack, previous learnings
- Ralph Tasks JSON with your task list
- NO external files needed -- the story is self-sufficient

## Start the Application

{{start_command}}

## Work on Tasks

Open the story file and find the `## Ralph Tasks` JSON section.
Find the FIRST task where `"passes": false`.

Work on exactly ONE task:
1. Read the task title, steps, and acceptanceCriteria
2. Implement following the story's Dev Notes guidance
3. Run checks:
{{check_commands}}

## Verify

{{verification_instructions}}

## Log Progress

Append a dated progress entry to activity.md describing:
- Task id and title worked on
- What you changed (files created/modified)
- Commands run and their results
- Any issues encountered and how you resolved them

## Update Task Status

When the task is confirmed working:
1. In the Ralph Tasks JSON, set this task's `"passes"` field from `false` to `true`
2. Mark the corresponding checkbox `[x]` in the Tasks/Subtasks section
3. Update the File List in the story's Dev Agent Record section
4. Do NOT reformat, reorder, or rewrite any other part of the JSON array

## Commit Changes

Make one git commit for this task only:
```
git add -A
git commit -m "feat({{story_key}}): [brief description of what was implemented]"
```

Do NOT run `git init`, change git remotes, or push.

## Important Rules

- ONLY work on a SINGLE task per iteration
- Always verify before marking a task as passing
- Always log progress in activity.md
- Always commit after completing a task
- Use ONLY the story file and existing codebase for context
- Do NOT reformat the Ralph Tasks JSON -- only change the `passes` field

## Completion

When ALL tasks in the Ralph Tasks JSON have `"passes": true`, output:

<promise>COMPLETE</promise>
