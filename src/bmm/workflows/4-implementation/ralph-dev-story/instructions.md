# Ralph Dev Story Workflow

Prepare and optionally launch Ralph Wiggum autonomous loop execution for a BMAD story.

## Step 1: Find Target Story

1. If `story_file` is provided by the user, use it directly.
2. Otherwise, check `sprint-status.yaml` for the first story with status `ready-for-dev`.
3. If no sprint status file exists, search `{story_dir}` for story files with `Status: ready-for-dev`.
4. Read the COMPLETE story file.
5. Verify story has a `## Ralph Tasks` section with valid JSON.
6. If no Ralph Tasks section exists, HALT with message:
   > "Story missing Ralph Tasks JSON section. Re-create the story using the `create-story` (CS) workflow, which now generates Ralph Tasks automatically."

## Step 2: Validate Ralph Tasks

1. Parse the Ralph Tasks JSON array from the story file.
2. Verify it is a valid JSON array.
3. Verify each task object has required fields: `id`, `category`, `description`, `steps`, `verification`, `passes`.
4. Count tasks with `"passes": false` (remaining work).
5. If all tasks already have `"passes": true`, HALT with message:
   > "All ralph tasks already complete. Run code-review (CR) workflow next."
6. Report: "Found {{total_tasks}} tasks, {{remaining_tasks}} remaining."

## Step 3: Extract Build Context from Story

1. Read the `## Dev Notes` section to determine:
   - **Tech stack and frameworks** used
   - **Start command** (e.g., `npm run dev`, `python manage.py runserver`, `pnpm dev`)
   - **Build/lint/test commands** (e.g., `npm run build`, `npm run lint`, `npm test`)
   - **Browser verification URL** (e.g., `http://localhost:3000`)
2. Extract `story_key` from the filename (e.g., `1-2-user-auth` from `1-2-user-auth.md`).
3. Determine **verification mode** based on story content:
   - **UI story** (has frontend/visual components): Use `agent-browser` for screenshots + visual verification.
   - **Backend/API story** (no UI): Use test execution for verification.
   - **Mixed**: Use both agent-browser and tests.

## Step 4: Generate PROMPT.md

1. Read `ralph-prompt.template.md` from the workflow's installed path.
2. Replace template variables with story-specific values:
   - `{{story_file_path}}` → actual story file path relative to project root
   - `{{story_key}}` → extracted story key
   - `{{start_command}}` → from Dev Notes (or `# No start command needed` if backend-only)
   - `{{check_commands}}` → build/lint/test commands from Dev Notes
   - `{{verification_instructions}}` → based on verification mode:
     - For UI: agent-browser open, snapshot, screenshot instructions
     - For backend: run test suite instructions
     - For mixed: both
3. Write the generated PROMPT.md to the **project root**.
4. Report: "PROMPT.md generated at project root."

## Step 5: Initialize Activity Log

Create or reset `activity.md` at the project root with this content:

```markdown
# Ralph Dev Activity Log - Story {{story_key}}

## Current Status
**Story:** {{story_key}}
**Started:** {{date}}
**Tasks:** 0/{{total_tasks}} completed

---

## Session Log
<!-- Ralph iterations will append dated entries below -->
```

## Step 6: Ensure Ralph Scripts Exist

1. Check for `ralph.sh` at the project root.
   - If missing, generate the standard Ralph Wiggum loop script (reads PROMPT.md, runs claude, checks for `<promise>COMPLETE</promise>`, loops up to max iterations).
2. Check for `ralph-bmad.sh` at the project root.
   - If missing, generate the BMAD-aware wrapper script (updates story status ready-for-dev → in-progress → review, wraps ralph.sh).
3. Make both scripts executable: `chmod +x ralph.sh ralph-bmad.sh`

## Step 7: Validate Setup

Run through this checklist and report status:

- [ ] Story file exists and has `ready-for-dev` status
- [ ] Story file has valid Ralph Tasks JSON section
- [ ] Remaining ralph tasks have `"passes": false`
- [ ] PROMPT.md generated and references the story file
- [ ] activity.md initialized
- [ ] ralph-bmad.sh exists and is executable
- [ ] ralph.sh exists and is executable
- [ ] Start command extracted (or determined unnecessary)
- [ ] Check commands extracted from Dev Notes
- [ ] Verification mode determined (browser/tests/both)

If any item fails, report the issue and suggest how to fix it.

## Step 8: Launch or Instruct

Present the user with options:

- **[L] Launch now**: Execute `./ralph-bmad.sh {{story_file}} {{max_iterations}}`
- **[M] Manual**: Display the command for manual execution later
- **[I] Adjust iterations**: Let user change `max_iterations` (default: 20) before launching

If the user chooses to launch, execute the command. If not, display:

```
Ready to go! Run this command when you're ready:

./ralph-bmad.sh {{story_file}} {{max_iterations}}

Monitor progress:
- activity.md — iteration-by-iteration log
- screenshots/ — visual verification (if UI story)
- git log — one commit per completed task
```
