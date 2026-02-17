---
title: "Getting Started"
description: Install SKAD and build your first project
---

Build software faster using AI-powered workflows with specialized agents that guide you through planning, architecture, and implementation.

## What You'll Learn

- Install and initialize SKAD Method for a new project
- Choose the right planning track for your project size
- Progress through phases from requirements to working code
- Use agents and workflows effectively

:::note[Prerequisites]
- **Node.js 20+** — Required for the installer
- **Git** — Recommended for version control
- **AI-powered IDE** — Claude Code, Cursor, Windsurf, or similar
- **A project idea** — Even a simple one works for learning
:::

:::tip[Quick Path]
**Install** → `npx skad-method install`
**Plan** → PM creates PRD, Architect creates architecture
**Build** → SM manages sprints, DEV implements stories
**Fresh chats** for each workflow to avoid context issues.
:::

## Understanding SKAD

SKAD helps you build software through guided workflows with specialized AI agents. The process follows four phases:

| Phase | Name           | What Happens                                        |
| ----- | -------------- | --------------------------------------------------- |
| 1     | Analysis       | Brainstorming, research, product brief *(optional)* |
| 2     | Planning       | Create requirements (PRD or tech-spec)              |
| 3     | Solutioning    | Design architecture *(SKAD Method/Enterprise only)* |
| 4     | Implementation | Build epic by epic, story by story                  |

**[Open the Workflow Map](../reference/workflow-map.md)** to explore phases, workflows, and context management.

Based on your project's complexity, SKAD offers three planning tracks:

| Track           | Best For                                               | Documents Created                      |
| --------------- | ------------------------------------------------------ | -------------------------------------- |
| **Quick Flow**  | Bug fixes, simple features, clear scope (1-15 stories) | Tech-spec only                         |
| **SKAD Method** | Products, platforms, complex features (10-50+ stories) | PRD + Architecture + UX                |
| **Enterprise**  | Compliance, multi-tenant systems (30+ stories)         | PRD + Architecture + Security + DevOps |

:::note
Story counts are guidance, not definitions. Choose your track based on planning needs, not story math.
:::

## Installation

Open a terminal in your project directory and run:

```bash
npx skad-method install
```

When prompted to select modules, choose **SKAD Method**.

The installer creates two folders:
- `_skad/` — agents, workflows, tasks, and configuration
- `_skad-output/` — empty for now, but this is where your artifacts will be saved

Open your AI IDE in the project folder. Run the `help` workflow (`/skad-help`) to see what to do next — it detects what you've completed and recommends the next step.

:::note[How to Load Agents and Run Workflows]
Each workflow has a **slash command** you run in your IDE (e.g., `/skad-skm-create-prd`). Running a workflow command automatically loads the appropriate agent — you don't need to load agents separately. You can also load an agent directly for general conversation (e.g., `/skad-agent-skm-pm` for the PM agent).
:::

:::caution[Fresh Chats]
Always start a fresh chat for each workflow. This prevents context limitations from causing issues.
:::

## Step 1: Create Your Plan

Work through phases 1-3. **Use fresh chats for each workflow.**

### Phase 1: Analysis (Optional)

All workflows in this phase are optional:
- **brainstorming** (`/skad-brainstorming`) — Guided ideation
- **research** (`/skad-skm-research`) — Market and technical research
- **create-product-brief** (`/skad-skm-create-product-brief`) — Recommended foundation document

### Phase 2: Planning (Required)

**For SKAD Method and Enterprise tracks:**
1. Load the **PM agent** (`/skad-agent-skm-pm`) in a new chat
2. Run the `prd` workflow (`/skad-skm-create-prd`)
3. Output: `PRD.md`

**For Quick Flow track:**
- Use the `quick-spec` workflow (`/skad-skm-quick-spec`) instead of PRD, then skip to implementation

:::note[UX Design (Optional)]
If your project has a user interface, load the **UX-Designer agent** (`/skad-agent-skm-ux-designer`) and run the UX design workflow (`/skad-skm-create-ux-design`) after creating your PRD.
:::

### Phase 3: Solutioning (SKAD Method/Enterprise)

**Create Architecture**
1. Load the **Architect agent** (`/skad-agent-skm-architect`) in a new chat
2. Run `create-architecture` (`/skad-skm-create-architecture`)
3. Output: Architecture document with technical decisions

**Create Epics and Stories**

:::tip[V6 Improvement]
Epics and stories are now created *after* architecture. This produces better quality stories because architecture decisions (database, API patterns, tech stack) directly affect how work should be broken down.
:::

1. Load the **PM agent** (`/skad-agent-skm-pm`) in a new chat
2. Run `create-epics-and-stories` (`/skad-skm-create-epics-and-stories`)
3. The workflow uses both PRD and Architecture to create technically-informed stories

**Implementation Readiness Check** *(Highly Recommended)*
1. Load the **Architect agent** (`/skad-agent-skm-architect`) in a new chat
2. Run `check-implementation-readiness` (`/skad-skm-check-implementation-readiness`)
3. Validates cohesion across all planning documents

## Step 2: Build Your Project

Once planning is complete, move to implementation. **Each workflow should run in a fresh chat.**

### Initialize Sprint Planning

Load the **SM agent** (`/skad-agent-skm-sm`) and run `sprint-planning` (`/skad-skm-sprint-planning`). This creates `sprint-status.yaml` to track all epics and stories.

### The Build Cycle

For each story, repeat this cycle with fresh chats:

| Step | Agent | Workflow       | Command                    | Purpose                            |
| ---- | ----- | -------------- | -------------------------- | ---------------------------------- |
| 1    | SM    | `create-story` | `/skad-skm-create-story`  | Create story file from epic        |
| 2    | DEV   | `dev-story`    | `/skad-skm-dev-story`     | Implement the story                |
| 3    | DEV   | `code-review`  | `/skad-skm-code-review`   | Quality validation *(recommended)* |

After completing all stories in an epic, load the **SM agent** (`/skad-agent-skm-sm`) and run `retrospective` (`/skad-skm-retrospective`).

## What You've Accomplished

You've learned the foundation of building with SKAD:

- Installed SKAD and configured it for your IDE
- Initialized a project with your chosen planning track
- Created planning documents (PRD, Architecture, Epics & Stories)
- Understood the build cycle for implementation

Your project now has:

```text
your-project/
├── _skad/                         # SKAD configuration
├── _skad-output/
│   ├── PRD.md                     # Your requirements document
│   ├── architecture.md            # Technical decisions
│   ├── epics/                     # Epic and story files
│   └── sprint-status.yaml         # Sprint tracking
└── ...
```

## Quick Reference

| Workflow                         | Command                                    | Agent     | Purpose                              |
| -------------------------------- | ------------------------------------------ | --------- | ------------------------------------ |
| `help`                           | `/skad-help`                               | Any       | Get guidance on what to do next      |
| `prd`                            | `/skad-skm-create-prd`                     | PM        | Create Product Requirements Document |
| `create-architecture`            | `/skad-skm-create-architecture`            | Architect | Create architecture document         |
| `create-epics-and-stories`       | `/skad-skm-create-epics-and-stories`       | PM        | Break down PRD into epics            |
| `check-implementation-readiness` | `/skad-skm-check-implementation-readiness` | Architect | Validate planning cohesion           |
| `sprint-planning`                | `/skad-skm-sprint-planning`                | SM        | Initialize sprint tracking           |
| `create-story`                   | `/skad-skm-create-story`                   | SM        | Create a story file                  |
| `dev-story`                      | `/skad-skm-dev-story`                      | DEV       | Implement a story                    |
| `code-review`                    | `/skad-skm-code-review`                    | DEV       | Review implemented code              |

## Common Questions

**Do I always need architecture?**
Only for SKAD Method and Enterprise tracks. Quick Flow skips from tech-spec to implementation.

**Can I change my plan later?**
Yes. The SM agent has a `correct-course` workflow (`/skad-skm-correct-course`) for handling scope changes.

**What if I want to brainstorm first?**
Load the Analyst agent (`/skad-agent-skm-analyst`) and run `brainstorming` (`/skad-brainstorming`) before starting your PRD.

**Do I need to follow a strict order?**
Not strictly. Once you learn the flow, you can run workflows directly using the Quick Reference above.

## Getting Help

- **During workflows** — Agents guide you with questions and explanations
- **Community** — [Discord](https://discord.gg/gk8jAdXWmj) (#skad-method-help, #report-bugs-and-issues)
- **Stuck?** — Run `help` (`/skad-help`) to see what to do next

## Key Takeaways

:::tip[Remember These]
- **Always use fresh chats** — Start a new chat for each workflow
- **Track matters** — Quick Flow uses quick-spec; Method/Enterprise need PRD and architecture
- **Use `help` (`/skad-help`) when stuck** — It detects your progress and suggests next steps
:::

Ready to start? Install SKAD and let the agents guide you through your first project.
