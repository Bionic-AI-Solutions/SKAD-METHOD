# Ralph Task Decomposition Guide

Best practices for creating Ralph Tasks JSON that executes reliably in the autonomous loop. Each task runs in a **fresh context** with no memory of previous iterations — the task definition is the agent's only instruction.

---

## JSON Schema (Required Fields)

```json
{
  "id": "task-N",
  "title": "Short imperative description of what to build",
  "acceptanceCriteria": ["AC1", "AC3"],
  "steps": ["Specific actionable step with file path"],
  "checkCommands": ["bash command that verifies completion"],
  "passes": false
}
```

| Field | Type | Purpose |
|-------|------|---------|
| `id` | `"task-N"` | Sequential identifier. Tasks execute in order. |
| `title` | string | Imperative, action-oriented. Shows in Ralph's status output. |
| `acceptanceCriteria` | string[] | Which story ACs this task addresses (e.g. `"AC1"`, `"AC2"`). |
| `steps` | string[] | Ordered implementation instructions. Must include file paths. |
| `checkCommands` | string[] | Bash commands Ralph runs to verify task completion. |
| `passes` | boolean | Always `false` initially. Ralph sets to `true` when verified. |

---

## Task Sizing

Each task must complete in **one Claude CLI iteration** (~3-5 minutes):

- **1-3 files** created or modified per task
- **Single concern** — one logical unit of work (e.g., "create migration", "implement tool", "write tests")
- If a task touches more than 3 files, split it

### Sizing Examples

| Too Large | Right Size |
|-----------|------------|
| "Build the user auth system" | "Create auth middleware with JWT validation" |
| "Create all database tables" | "Create migration 005 — user and session tables" |
| "Implement and test the API" | Task 1: "Implement /users endpoint" → Task 2: "Write integration tests for /users" |
| "Set up service with Docker and tests" | Task 1: "Scaffold service" → Task 2: "Add Dockerfile and docker-compose" → Task 3: "Write tests" |

---

## Writing Good Steps

Steps are the agent's primary instructions. They must be **specific and unambiguous**.

### Rules

1. **Include file paths** — every step that creates/modifies a file must name it
2. **Include concrete details** — function signatures, SQL column types, import paths
3. **Reference existing patterns** — "following the pattern in `services/mcp-schema/src/tools/`"
4. **One action per step** — don't combine "create file AND update imports" in one step
5. **No vague language** — avoid "set up", "configure properly", "implement as needed"

### Good Steps

```json
"steps": [
  "Create infra/migrations/011-tenant-lifecycle.sql",
  "Define tenant_status enum: DO $$ BEGIN CREATE TYPE tenant_status AS ENUM ('active', 'suspended'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;",
  "ALTER TABLE tenants ADD COLUMN IF NOT EXISTS status tenant_status NOT NULL DEFAULT 'active'",
  "Add RLS policy matching pattern from 003-rls-policies.sql"
]
```

### Bad Steps

```json
"steps": [
  "Create the migration file",
  "Add necessary columns",
  "Set up security"
]
```

---

## Writing Good checkCommands

checkCommands are **bash commands** that Ralph runs to verify task completion. They must:

1. **Return non-zero on failure** — so Ralph can detect incomplete tasks
2. **Be specific** — verify the exact artifacts created
3. **Be fast** — no long-running processes
4. **Not modify state** — read-only verification

### Patterns

```json
"checkCommands": [
  "ls path/to/expected/file.ts",
  "grep -c 'expected_function' path/to/file.ts",
  "npm run build 2>&1 | tail -5",
  "npx vitest run path/to/test.ts --reporter=verbose 2>&1 | tail -10"
]
```

### Common Verifications

| What to verify | Command pattern |
|---------------|----------------|
| File exists | `ls path/to/file` |
| Content present | `grep -c 'pattern' path/to/file` |
| Build succeeds | `npm run build 2>&1 \| tail -5` |
| Tests pass | `npx vitest run path/to/test.ts 2>&1 \| tail -10` |
| Service in docker-compose | `grep -c 'service-name' docker-compose.yml` |
| Executable permission | `test -x scripts/myscript.sh && echo OK` |

---

## Task Sequencing

Tasks execute **strictly in order**. Each task can only depend on **previous** tasks, never future ones.

### Canonical Sequence

1. **Database migrations** — schema changes first (everything else depends on tables existing)
2. **Scaffolding** — package.json, tsconfig, config files, directory structure
3. **Core implementation** — business logic, tool handlers, API endpoints
4. **Supporting features** — audit logging, error handling, middleware
5. **Infrastructure** — Dockerfile, docker-compose additions, CLI scripts
6. **Tests** — integration/unit tests last (they verify everything above)

### Why This Order Works

- Migration before code: code references tables that must exist in the schema
- Scaffold before implementation: implementation needs package.json, config
- Implementation before tests: tests exercise the implementation
- Infrastructure after implementation: Dockerfile copies built artifacts

---

## Deriving Tasks from Acceptance Criteria

Map each AC to one or more tasks. Every AC must be covered.

### Process

1. Group ACs by **implementation layer** (database, service, API, tests)
2. Order groups following the canonical sequence above
3. Split any group larger than 3 files into multiple tasks
4. Ensure each task's `acceptanceCriteria` field lists the ACs it addresses
5. The final task (usually tests) should reference ALL ACs

### Example Mapping

| AC | Task |
|----|------|
| AC1: Tenant created <2s | task-1 (migration), task-3 (create tool), task-7 (test) |
| AC2: Twilio phone stored | task-1 (migration columns), task-3 (create tool stores it), task-7 (test) |
| AC7: Audit trail | task-1 (audit table), task-5 (audit logging), task-7 (test) |

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Mega-task with 10+ steps | Agent loses focus, times out | Split into 2-3 focused tasks |
| "Implement everything" step | Vague, agent interprets freely | List specific files and functions |
| No checkCommands | Ralph can't verify completion | Add at least `ls` + `grep` + build check |
| Test task before implementation | Tests fail because code doesn't exist yet | Tests always last |
| checkCommands that modify state | Side effects between iterations | Use read-only commands (ls, grep, cat) |
| Forward dependencies | Task N references Task N+1 output | Reorder so dependencies flow downward |

---

## Template: Minimal Task

```json
{
  "id": "task-1",
  "title": "Create migration 005 — users and sessions",
  "acceptanceCriteria": ["AC1", "AC2"],
  "steps": [
    "Create infra/migrations/005-users-sessions.sql",
    "CREATE TABLE users (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), email VARCHAR(255) UNIQUE NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW())",
    "CREATE TABLE sessions (id UUID PRIMARY KEY, user_id UUID REFERENCES users(id) ON DELETE CASCADE, expires_at TIMESTAMPTZ NOT NULL)",
    "Add RLS policies for both tables",
    "Ensure migration is idempotent (IF NOT EXISTS patterns)"
  ],
  "checkCommands": [
    "ls infra/migrations/005-users-sessions.sql",
    "grep -c 'CREATE TABLE users' infra/migrations/005-users-sessions.sql",
    "grep -c 'CREATE TABLE sessions' infra/migrations/005-users-sessions.sql"
  ],
  "passes": false
}
```
