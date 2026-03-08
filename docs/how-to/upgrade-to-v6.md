---
title: "How to Upgrade to v6"
description: Migrate from SKad v4 to v6
sidebar:
  order: 3
---

Use the SKad installer to upgrade from v4 to v6, which includes automatic detection of legacy installations and migration assistance.

## When to Use This

- You have SKad v4 installed (`.skad-method` folder)
- You want to migrate to the new v6 architecture
- You have existing planning artifacts to preserve

:::note[Prerequisites]
- Node.js 20+
- Existing SKad v4 installation
:::

## Steps

### 1. Run the Installer

Follow the [Installer Instructions](./install-skad.md).

### 2. Handle Legacy Installation

When v4 is detected, you can:

- Allow the installer to back up and remove `.skad-method`
- Exit and handle cleanup manually

If you named your skad method folder something else - you will need to manually remove the folder yourself.

### 3. Clean Up IDE Skills

Manually remove legacy v4 IDE commands/skills - for example if you have Claude Code, look for any nested folders that start with skad and remove them:

- `.claude/commands/`

The new v6 skills are installed to:

- `.claude/skills/`

### 4. Migrate Planning Artifacts

**If you have planning documents (Brief/PRD/UX/Architecture):**

Move them to `_skad-output/planning-artifacts/` with descriptive names:

- Include `PRD` in filename for PRD documents
- Include `brief`, `architecture`, or `ux-design` accordingly
- Sharded documents can be in named subfolders

**If you're mid-planning:** Consider restarting with v6 workflows. Use your existing documents as inputs—the new progressive discovery workflows with web search and IDE plan mode produce better results.

### 5. Migrate In-Progress Development

If you have stories created or implemented:

1. Complete the v6 installation
2. Place `epics.md` or `epics/epic*.md` in `_skad-output/planning-artifacts/`
3. Run the Scrum Master's `skad-sprint-planning` workflow
4. Tell the SM which epics/stories are already complete

## What You Get

**v6 unified structure:**

```text
your-project/
├── _skad/               # Single installation folder
│   ├── _config/         # Your customizations
│   │   └── agents/      # Agent customization files
│   ├── core/            # Universal core framework
│   ├── bmm/             # SKad Method module
│   ├── bmb/             # SKad Builder
│   └── cis/             # Creative Intelligence Suite
└── _skad-output/        # Output folder (was doc folder in v4)
```

## Module Migration

| v4 Module                     | v6 Status                                 |
| ----------------------------- | ----------------------------------------- |
| `.skad-2d-phaser-game-dev`    | Integrated into BMGD Module               |
| `.skad-2d-unity-game-dev`     | Integrated into BMGD Module               |
| `.skad-godot-game-dev`        | Integrated into BMGD Module               |
| `.skad-infrastructure-devops` | Deprecated — new DevOps agent coming soon |
| `.skad-creative-writing`      | Not adapted — new v6 module coming soon   |

## Key Changes

| Concept       | v4                                    | v6                                   |
| ------------- | ------------------------------------- | ------------------------------------ |
| **Core**      | `_skad-core` was actually SKad Method | `_skad/core/` is universal framework |
| **Method**    | `_skad-method`                        | `_skad/bmm/`                         |
| **Config**    | Modified files directly               | `config.yaml` per module             |
| **Documents** | Sharded or unsharded required setup   | Fully flexible, auto-scanned         |
