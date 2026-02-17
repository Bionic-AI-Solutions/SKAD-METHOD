# Ralph QA Automate Workflow

Generate tests autonomously via the Ralph Wiggum loop, one feature per iteration.

## Step 1: Detect Test Framework

1. Scan `package.json`, `pyproject.toml`, `Cargo.toml`, or equivalent for test framework dependencies.
2. Check for existing test files and patterns (e.g., `*.test.ts`, `*.spec.js`, `test_*.py`).
3. Identify the test runner and assertion library in use.
4. If no framework detected:
   - Analyze the project stack
   - Recommend an appropriate framework (e.g., Vitest for Vite, Jest for React, Pytest for Python)
   - Ask user for confirmation before proceeding
5. Record the detected framework and test run command (e.g., `npm test`, `pytest`, `cargo test`).

## Step 2: Discover Testable Features

1. Scan the codebase for features, components, and endpoints that need test coverage.
2. Categorize each by test type:
   - **unit-test**: Individual functions, utilities, helpers, models
   - **integration-test**: Component interactions, service layers, middleware
   - **api-test**: API endpoints, request/response contracts
   - **e2e-test**: User flows, critical paths, UI interactions
3. Check for existing test coverage to identify gaps.
4. Prioritize by:
   - Critical business logic (highest priority)
   - Coverage gaps (no existing tests)
   - Recently modified code
   - Complex or error-prone areas

## Step 3: Generate Test Plan with Ralph Tasks JSON

Create `test-plan.md` at the project root with this structure:

```markdown
# Test Plan - Ralph QA Automate

## Test Framework
- **Framework:** {{detected_framework}}
- **Test Command:** {{test_command}}
- **Config File:** {{config_file_if_any}}

## Feature Inventory
{{list of features discovered with their test type categories}}

## Tasks / Subtasks

- [ ] Generate {{test_type}} tests for {{feature_1}}
- [ ] Generate {{test_type}} tests for {{feature_2}}
...

## Ralph Tasks

```json
[
  {
    "id": "test-1",
    "category": "{{test_type}}",
    "description": "Generate tests for {{feature_name}}",
    "acceptance_criteria": ["All generated tests pass on first run"],
    "steps": [
      "Analyze {{feature_source_files}} source code",
      "Write comprehensive {{test_type}} tests using {{framework}}",
      "Cover happy path + critical edge cases",
      "Run tests with {{test_command}}",
      "Verify all new tests pass"
    ],
    "verification": "{{test_command}}",
    "passes": false
  }
]
`` `
```

## Step 4: Generate PROMPT.md

1. Read `ralph-qa-prompt.template.md` from the workflow's installed path.
2. Replace template variables:
   - `{{test_framework}}` → detected framework name
   - `{{test_command}}` → test run command
3. Write PROMPT.md to the project root.

## Step 5: Initialize Activity Log and Validate

1. Create or reset `activity.md` at project root:
   ```markdown
   # Ralph QA Activity Log

   ## Current Status
   **Started:** {{date}}
   **Framework:** {{test_framework}}
   **Features to Test:** {{count}}

   ---

   ## Session Log
   <!-- Ralph iterations will append dated entries here -->
   ```

2. Ensure ralph scripts exist (ralph.sh, ralph-skad.sh) and are executable.

3. Validate:
   - [ ] test-plan.md created with valid Ralph Tasks JSON
   - [ ] PROMPT.md references @test-plan.md @activity.md
   - [ ] activity.md initialized
   - [ ] ralph scripts executable
   - [ ] Test framework detected and test command known

## Step 6: Launch or Instruct

Present the user with options:

- **[L] Launch now**: Execute `./ralph-skad.sh test-plan.md {{max_iterations}}`
- **[M] Manual**: Display the command for manual execution
- **[I] Adjust iterations**: Change max_iterations before launching

If not launching immediately, display:
```
Ready to generate tests! Run:

./ralph-skad.sh test-plan.md {{max_iterations}}

Each iteration will:
1. Pick the next untested feature
2. Generate comprehensive tests
3. Run the test suite to verify
4. Commit the new test files
```
