---
title: "Getting Started"
description: Install SKad and build your first project
---

Build software faster using AI-powered workflows with specialized agents that guide you through planning, architecture, and implementation.

## What You'll Learn

- Install and initialize SKad Method for a new project
- Use **SKad-Help** — your intelligent guide that knows what to do next
- Choose the right planning track for your project size
- Progress through phases from requirements to working code
- Use agents and workflows effectively

:::note[Prerequisites]
- **Node.js 20+** — Required for the installer
- **Git** — Recommended for version control
- **AI-powered IDE** — Claude Code, Cursor, or similar
- **A project idea** — Even a simple one works for learning
:::

:::tip[The Easiest Path]
**Install** → `npx skad-method install`
**Ask** → `/skad-help what should I do first?`
**Build** → Let SKad-Help guide you workflow by workflow
:::

## Meet SKad-Help: Your Intelligent Guide

**SKad-Help is the fastest way to get started with SKad.** You don't need to memorize workflows or phases — just ask, and SKad-Help will:

- **Inspect your project** to see what's already been done
- **Show your options** based on which modules you have installed
- **Recommend what's next** — including the first required task
- **Answer questions** like "I have a SaaS idea, where do I start?"

### How to Use SKad-Help

Run it in your AI IDE by invoking the skill:

```
skad-help
```

Or combine it with a question for context-aware guidance:

```
skad-help I have an idea for a SaaS product, I already know all the features I want. where do I get started?
```

SKad-Help will respond with:
- What's recommended for your situation
- What the first required task is
- What the rest of the process looks like

### It Powers Workflows Too

SKad-Help doesn't just answer questions — **it automatically runs at the end of every workflow** to tell you exactly what to do next. No guessing, no searching docs — just clear guidance on the next required workflow.

:::tip[Start Here]
After installing SKad, run `/skad-help` immediately. It will detect what modules you have installed and guide you to the right starting point for your project.
:::

## Understanding SKad

SKad helps you build software through guided workflows with specialized AI agents. The process follows four phases:

| Phase | Name           | What Happens                                        |
| ----- | -------------- | --------------------------------------------------- |
| 1     | Analysis       | Brainstorming, research, product brief *(optional)* |
| 2     | Planning       | Create requirements (PRD or tech-spec)              |
| 3     | Solutioning    | Design architecture *(SKad Method/Enterprise only)* |
| 4     | Implementation | Build epic by epic, story by story                  |

**[Open the Workflow Map](../reference/workflow-map.md)** to explore phases, workflows, and context management.

Based on your project's complexity, SKad offers three planning tracks:

| Track           | Best For                                               | Documents Created                      |
| --------------- | ------------------------------------------------------ | -------------------------------------- |
| **Quick Flow**  | Bug fixes, simple features, clear scope (1-15 stories) | Tech-spec only                         |
| **SKad Method** | Products, platforms, complex features (10-50+ stories) | PRD + Architecture + UX                |
| **Enterprise**  | Compliance, multi-tenant systems (30+ stories)         | PRD + Architecture + Security + DevOps |

:::note
Story counts are guidance, not definitions. Choose your track based on planning needs, not story math.
:::

## Installation

Open a terminal in your project directory and run:

```bash
npx skad-method install
```

When prompted to select modules, choose **SKad Method**.

The installer creates two folders:
- `_skad/` — agents, workflows, tasks, and configuration
- `_skad-output/` — empty for now, but this is where your artifacts will be saved

:::tip[Your Next Step]
Open your AI IDE in the project folder and run:

```
/skad-help
```

SKad-Help will detect what you've completed and recommend exactly what to do next. You can also ask it questions like "What are my options?" or "I have a SaaS idea, where should I start?"
:::

:::note[How to Load Agents and Run Workflows]
Each workflow has a **skill** you invoke in your IDE (e.g., `/skad-create-prd`). Running a workflow skill automatically loads the appropriate agent — you don't need to load agents separately. You can also invoke an agent directly for general conversation (e.g., `/skad-pm` for the PM agent).
:::

:::caution[Fresh Chats]
Always start a fresh chat for each workflow. This prevents context limitations from causing issues.
:::

## Step 1: Create Your Plan

Work through phases 1-3. **Use fresh chats for each workflow.**

:::tip[Project Context (Optional)]
Before starting, consider creating `project-context.md` to document your technical preferences and implementation rules. This ensures all AI agents follow your conventions throughout the project.

Create it manually at `_skad-output/project-context.md` or generate it after architecture using `/skad-generate-project-context`. [Learn more](../explanation/project-context.md).
:::

### Phase 1: Analysis (Optional)

All workflows in this phase are optional:
- **brainstorming** (`/skad-brainstorming`) — Guided ideation
- **research** (`/skad-research`) — Market and technical research
- **create-product-brief** (`/skad-create-product-brief`) — Recommended foundation document

### Phase 2: Planning (Required)

**For SKad Method and Enterprise tracks:**
1. Invoke the **PM agent** (`/skad-pm`) in a new chat
2. Run the `skad-create-prd` workflow (`/skad-create-prd`)
3. Output: `PRD.md`

**For Quick Flow track:**
- Use the `skad-quick-spec` workflow (`/skad-quick-spec`) instead of PRD, then skip to implementation

:::note[UX Design (Optional)]
If your project has a user interface, invoke the **UX-Designer agent** (`/skad-ux-designer`) and run the UX design workflow (`/skad-create-ux-design`) after creating your PRD.
:::

### Phase 3: Solutioning (SKad Method/Enterprise)

**Create Architecture**
1. Invoke the **Architect agent** (`/skad-architect`) in a new chat
2. Run `skad-create-architecture` (`/skad-create-architecture`)
3. Output: Architecture document with technical decisions

**Create Epics and Stories**

:::tip[V6 Improvement]
Epics and stories are now created *after* architecture. This produces better quality stories because architecture decisions (database, API patterns, tech stack) directly affect how work should be broken down.
:::

1. Invoke the **PM agent** (`/skad-pm`) in a new chat
2. Run `skad-create-epics-and-stories` (`/skad-create-epics-and-stories`)
3. The workflow uses both PRD and Architecture to create technically-informed stories

**Implementation Readiness Check** *(Highly Recommended)*
1. Invoke the **Architect agent** (`/skad-architect`) in a new chat
2. Run `skad-check-implementation-readiness` (`/skad-check-implementation-readiness`)
3. Validates cohesion across all planning documents

## Step 2: Build Your Project

Once planning is complete, move to implementation. **Each workflow should run in a fresh chat.**

### Initialize Sprint Planning

Invoke the **SM agent** (`/skad-sm`) and run `skad-sprint-planning` (`/skad-sprint-planning`). This creates `sprint-status.yaml` to track all epics and stories.

### The Build Cycle

For each story, repeat this cycle with fresh chats:

| Step | Agent | Workflow       | Command                    | Purpose                            |
| ---- | ----- | -------------- | -------------------------- | ---------------------------------- |
| 1    | SM    | `skad-create-story` | `/skad-create-story`  | Create story file from epic        |
| 2    | DEV   | `skad-dev-story`    | `/skad-dev-story`     | Implement the story                |
| 3    | DEV   | `skad-code-review`  | `/skad-code-review`   | Quality validation *(recommended)* |

After completing all stories in an epic, invoke the **SM agent** (`/skad-sm`) and run `skad-retrospective` (`/skad-retrospective`).

## What You've Accomplished

You've learned the foundation of building with SKad:

- Installed SKad and configured it for your IDE
- Initialized a project with your chosen planning track
- Created planning documents (PRD, Architecture, Epics & Stories)
- Understood the build cycle for implementation

Your project now has:

```text
your-project/
├── _skad/                                   # SKad configuration
├── _skad-output/
│   ├── planning-artifacts/
│   │   ├── PRD.md                           # Your requirements document
│   │   ├── architecture.md                  # Technical decisions
│   │   └── epics/                           # Epic and story files
│   ├── implementation-artifacts/
│   │   └── sprint-status.yaml               # Sprint tracking
│   └── project-context.md                   # Implementation rules (optional)
└── ...
```

## Quick Reference

| Workflow                              | Command                                    | Agent     | Purpose                                         |
| ------------------------------------- | ------------------------------------------ | --------- | ----------------------------------------------- |
| **`skad-help`** ⭐                    | `/skad-help`                               | Any       | **Your intelligent guide — ask anything!**      |
| `skad-create-prd`                | `/skad-create-prd`                     | PM        | Create Product Requirements Document            |
| `skad-create-architecture`            | `/skad-create-architecture`            | Architect | Create architecture document                     |
| `skad-generate-project-context`       | `/skad-generate-project-context`           | Analyst   | Create project context file                     |
| `skad-create-epics-and-stories`       | `/skad-create-epics-and-stories`       | PM        | Break down PRD into epics            |
| `skad-check-implementation-readiness` | `/skad-check-implementation-readiness` | Architect | Validate planning cohesion           |
| `skad-sprint-planning`                | `/skad-sprint-planning`                | SM        | Initialize sprint tracking           |
| `skad-create-story`                   | `/skad-create-story`                   | SM        | Create a story file                  |
| `skad-dev-story`                      | `/skad-dev-story`                      | DEV       | Implement a story                    |
| `skad-code-review`                    | `/skad-code-review`                    | DEV       | Review implemented code              |

## Common Questions

**Do I always need architecture?**
Only for SKad Method and Enterprise tracks. Quick Flow skips from tech-spec to implementation.

**Can I change my plan later?**
Yes. The SM agent has a `skad-correct-course` workflow (`/skad-correct-course`) for handling scope changes.

**What if I want to brainstorm first?**
Invoke the Analyst agent (`/skad-analyst`) and run `skad-brainstorming` (`/skad-brainstorming`) before starting your PRD.

**Do I need to follow a strict order?**
Not strictly. Once you learn the flow, you can run workflows directly using the Quick Reference above.

## Getting Help

:::tip[First Stop: SKad-Help]
**Run `/skad-help` anytime** — it's the fastest way to get unstuck. Ask it anything:
- "What should I do after installing?"
- "I'm stuck on workflow X"
- "What are my options for Y?"
- "Show me what's been done so far"

SKad-Help inspects your project, detects what you've completed, and tells you exactly what to do next.
:::

- **During workflows** — Agents guide you with questions and explanations
- **Community** — [Discord](https://discord.gg/gk8jAdXWmj) (#skad-method-help, #report-bugs-and-issues)

## Key Takeaways

:::tip[Remember These]
- **Start with `/skad-help`** — Your intelligent guide that knows your project and options
- **Always use fresh chats** — Start a new chat for each workflow
- **Track matters** — Quick Flow uses quick-spec; Method/Enterprise need PRD and architecture
- **SKad-Help runs automatically** — Every workflow ends with guidance on what's next
:::

Ready to start? Install SKad, run `/skad-help`, and let your intelligent guide lead the way.
