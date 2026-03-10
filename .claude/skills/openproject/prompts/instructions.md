# OpenProject MCP Bridge

You have access to a full OpenProject project management instance via its MCP server.

**Endpoint:** `https://mcp.baisoln.com/openproject/mcp`
**Protocol:** JSON-RPC 2.0 over HTTPS POST
**Server:** OpenProject Server v2.14.5 (MCP protocol 2024-11-05)

## How to Call Tools

Use the Bash tool with `curl` to invoke any tool:

```bash
curl -s -X POST https://mcp.baisoln.com/openproject/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "<TOOL_NAME>",
      "arguments": { <TOOL_ARGS> }
    }
  }'
```

Parse the response: `result.content[0].text` contains the tool output (JSON string).

**RULES:**
- Always pretty-print results with `| python3 -c "import json,sys; print(json.dumps(json.loads(json.load(sys.stdin)['result']['content'][0]['text']), indent=2))"` for readability
- For bulk/destructive actions (delete, bulk_update), confirm with the user first
- Increment `"id"` for each call in a session to keep tracing clean
- If a call returns `error`, surface the message clearly and stop

---

## Tool Catalog (44 tools)

### Connection

#### `test_connection`
Verify API connectivity and key validity. No arguments.
```json
{ "name": "test_connection", "arguments": {} }
```

---

### Projects

#### `list_projects`
List all projects visible to the authenticated user.
```json
{ "name": "list_projects", "arguments": { "active_only": true } }
```
| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `active_only` | bool | `true` | Set `false` to include archived projects |

#### `get_project`
Get full details of a project.
```json
{ "name": "get_project", "arguments": { "project_id": 1 } }
```

#### `create_project`
```json
{
  "name": "create_project",
  "arguments": {
    "name": "My Project",
    "identifier": "my-project",
    "description": "Optional description",
    "public": false,
    "parent_id": null
  }
}
```
**Note:** Do NOT pass `"status"` — it causes a 500 error on the current OpenProject API. Projects are created as active by default.

| Param | Required | Notes |
|-------|----------|-------|
| `name` | yes | Display name |
| `identifier` | yes | URL slug, lowercase, hyphens |
| `description` | no | |
| `public` | no | default `false` |
| `status` | no | `"active"` \| `"archived"` |
| `parent_id` | no | For sub-projects |

#### `update_project`
Same params as `create_project` plus `project_id` (required). All other fields optional.

#### `delete_project`
**Destructive — confirm before calling.**
```json
{ "name": "delete_project", "arguments": { "project_id": 1 } }
```

---

### Work Packages

Work packages represent tasks, stories, epics, bugs, milestones, etc.

#### `list_work_packages`
```json
{
  "name": "list_work_packages",
  "arguments": {
    "project_id": 1,
    "status": "open",
    "offset": 0,
    "page_size": 25
  }
}
```
| Param | Required | Notes |
|-------|----------|-------|
| `project_id` | no | Filter by project |
| `status` | no | `"open"` \| `"closed"` \| `"all"` |
| `offset` | no | Pagination offset |
| `page_size` | no | Results per page |

#### `get_work_package`
```json
{ "name": "get_work_package", "arguments": { "work_package_id": 42 } }
```

#### `create_work_package`
```json
{
  "name": "create_work_package",
  "arguments": {
    "project_id": 1,
    "subject": "Implement login page",
    "type_id": 2,
    "description": "Markdown description",
    "priority_id": 8,
    "assignee_id": 5,
    "start_date": "2026-03-10",
    "due_date": "2026-03-20"
  }
}
```
| Param | Required | Notes |
|-------|----------|-------|
| `project_id` | yes | |
| `subject` | yes | Title |
| `type_id` | no | From `list_types` |
| `description` | no | Markdown |
| `priority_id` | no | From `list_priorities` |
| `assignee_id` | no | From `get_available_assignees` |
| `start_date` | no | ISO 8601 `YYYY-MM-DD` |
| `due_date` | no | ISO 8601 `YYYY-MM-DD` |

#### `update_work_package`
```json
{
  "name": "update_work_package",
  "arguments": {
    "work_package_id": 42,
    "subject": "New title",
    "status_id": 3,
    "percentage_done": 50
  }
}
```
All fields (except `work_package_id`) are optional. Include only what needs changing.

#### `delete_work_package`
**Destructive — confirm before calling.**
```json
{ "name": "delete_work_package", "arguments": { "work_package_id": 42 } }
```

#### `update_work_package_status`
Shortcut for status changes with optional comment and progress.
```json
{
  "name": "update_work_package_status",
  "arguments": {
    "work_package_id": 42,
    "status_id": 3,
    "comment": "Marking as in progress",
    "percentage_done": 25
  }
}
```

#### `get_work_package_schema`
Get allowed status transitions and field schema for a work package.
```json
{ "name": "get_work_package_schema", "arguments": { "work_package_id": 42 } }
```

---

### Search & Query

#### `search_work_packages`
Full-text search on subject.
```json
{
  "name": "search_work_packages",
  "arguments": {
    "query": "login",
    "project_id": 1,
    "type_ids": [2, 3],
    "status": "open",
    "limit": 20
  }
}
```

#### `query_work_packages`
Advanced query with flexible filters, sort, and grouping.
```json
{
  "name": "query_work_packages",
  "arguments": {
    "project_id": 1,
    "filters": [
      { "field": "assignee", "operator": "=", "values": ["5"] },
      { "field": "status", "operator": "o" }
    ],
    "sort_by": [["due_date", "asc"]],
    "group_by": "type",
    "page": 1,
    "page_size": 50
  }
}
```

---

### Bulk Operations

#### `bulk_create_work_packages`
```json
{
  "name": "bulk_create_work_packages",
  "arguments": {
    "project_id": 1,
    "work_packages": [
      { "subject": "Task A", "type_id": 2 },
      { "subject": "Task B", "type_id": 2, "assignee_id": 5 }
    ],
    "continue_on_error": true
  }
}
```

#### `bulk_update_work_packages`
**Confirm before calling on large sets.**
```json
{
  "name": "bulk_update_work_packages",
  "arguments": {
    "updates": [
      { "work_package_id": 42, "status_id": 3 },
      { "work_package_id": 43, "assignee_id": 7 }
    ],
    "continue_on_error": true
  }
}
```

---

### Hierarchy & Relations

#### `set_work_package_parent`
```json
{ "name": "set_work_package_parent", "arguments": { "work_package_id": 42, "parent_id": 10 } }
```

#### `remove_work_package_parent`
```json
{ "name": "remove_work_package_parent", "arguments": { "work_package_id": 42 } }
```

#### `get_work_package_children`
```json
{
  "name": "get_work_package_children",
  "arguments": {
    "parent_id": 10,
    "project_id": 1,
    "type_id": null,
    "status": "open",
    "include_descendants": false
  }
}
```

#### `get_work_package_hierarchy`
Full ancestor + descendant tree.
```json
{
  "name": "get_work_package_hierarchy",
  "arguments": {
    "work_package_id": 42,
    "include_ancestors": true,
    "include_descendants": true
  }
}
```

#### `create_work_package_relation`
Relation types: `"relates"`, `"duplicates"`, `"duplicated"`, `"blocks"`, `"blocked"`, `"precedes"`, `"follows"`, `"includes"`, `"partof"`, `"requires"`, `"required"`
```json
{
  "name": "create_work_package_relation",
  "arguments": {
    "from_work_package_id": 42,
    "to_work_package_id": 55,
    "relation_type": "blocks",
    "description": "Optional note",
    "lag": 0
  }
}
```

#### `list_work_package_relations`
```json
{ "name": "list_work_package_relations", "arguments": { "work_package_id": 42, "relation_type": null } }
```

#### `delete_work_package_relation`
```json
{ "name": "delete_work_package_relation", "arguments": { "relation_id": 7 } }
```

---

### Users & Assignment

#### `list_users`
```json
{ "name": "list_users", "arguments": { "active_only": true } }
```

#### `get_user`
```json
{ "name": "get_user", "arguments": { "user_id": 5 } }
```

#### `get_available_assignees`
Users who can be assigned in a specific project.
```json
{ "name": "get_available_assignees", "arguments": { "project_id": 1 } }
```

#### `assign_work_package`
```json
{
  "name": "assign_work_package",
  "arguments": {
    "work_package_id": 42,
    "assignee_id": 5,
    "responsible_id": null
  }
}
```

---

### Comments, Activity & Watchers

#### `add_work_package_comment`
```json
{
  "name": "add_work_package_comment",
  "arguments": {
    "work_package_id": 42,
    "comment": "Markdown comment text",
    "notify": true
  }
}
```

#### `list_work_package_activities`
```json
{ "name": "list_work_package_activities", "arguments": { "work_package_id": 42, "limit": 20 } }
```

#### `add_work_package_watcher`
```json
{ "name": "add_work_package_watcher", "arguments": { "work_package_id": 42, "user_id": 5 } }
```

#### `remove_work_package_watcher`
```json
{ "name": "remove_work_package_watcher", "arguments": { "work_package_id": 42, "user_id": 5 } }
```

#### `list_work_package_watchers`
```json
{ "name": "list_work_package_watchers", "arguments": { "work_package_id": 42 } }
```

---

### Time Tracking

#### `log_time`
```json
{
  "name": "log_time",
  "arguments": {
    "work_package_id": 42,
    "hours": 2.5,
    "activity_id": 3,
    "spent_on": "2026-03-09",
    "comment": "Reviewed and tested"
  }
}
```

#### `list_time_entries`
```json
{
  "name": "list_time_entries",
  "arguments": {
    "work_package_id": null,
    "project_id": 1,
    "user_id": 5,
    "from_date": "2026-03-01",
    "to_date": "2026-03-09"
  }
}
```

#### `list_time_entry_activities`
Activity categories available for time logging in a project.
```json
{ "name": "list_time_entry_activities", "arguments": { "project_id": 1 } }
```

---

### Attachments

#### `list_work_package_attachments`
```json
{ "name": "list_work_package_attachments", "arguments": { "work_package_id": 42 } }
```

#### `add_work_package_attachment`
```json
{
  "name": "add_work_package_attachment",
  "arguments": {
    "work_package_id": 42,
    "file_data": "<base64-encoded content>",
    "filename": "report.pdf",
    "content_type": "application/pdf",
    "description": "Monthly report"
  }
}
```

#### `delete_attachment`
**Destructive — confirm before calling.**
```json
{ "name": "delete_attachment", "arguments": { "attachment_id": 12 } }
```

---

### Metadata / Schema

#### `list_types`
Work package types (Task, Story, Epic, Bug, Milestone, etc.).
```json
{ "name": "list_types", "arguments": { "project_id": 1 } }
```

#### `list_statuses`
All status options. No arguments.
```json
{ "name": "list_statuses", "arguments": {} }
```

#### `list_priorities`
All priority levels. No arguments.
```json
{ "name": "list_priorities", "arguments": {} }
```

#### `list_custom_fields`
All custom fields in the instance. No arguments.
```json
{ "name": "list_custom_fields", "arguments": {} }
```

#### `update_work_package_custom_fields`
```json
{
  "name": "update_work_package_custom_fields",
  "arguments": {
    "work_package_id": 42,
    "custom_fields": {
      "customField1": "value",
      "customField3": true
    }
  }
}
```

---

## Typical Workflows

### Discover then act
1. `list_projects` → find `project_id`
2. `list_types` + `list_statuses` + `list_priorities` → find IDs
3. `get_available_assignees` → find `assignee_id`
4. `create_work_package` or `update_work_package`

### Status update with comment
1. `get_work_package_schema` → confirm allowed transitions
2. `update_work_package_status` with `comment`

### Build a hierarchy
1. Create parent WP → get its `id`
2. `bulk_create_work_packages` for children
3. `set_work_package_parent` for each child, or pass `parent_id` in create args

### Query a user's open tasks
1. `list_users` → find `user_id`
2. `query_work_packages` with `filters: [{ field: "assignee", operator: "=", values: ["<user_id>"] }, { field: "status", operator: "o" }]`
