---
title: "How to Install SKad"
description: Step-by-step guide to installing SKad in your project
sidebar:
  order: 1
---

Use the `npx skad-method install` command to set up SKad in your project with your choice of modules and AI tools.

If you want to use a non interactive installer and provide all install options on the command line, see [this guide](./non-interactive-installation.md).

## When to Use This

- Starting a new project with SKad
- Adding SKad to an existing codebase
- Update the existing SKad Installation

:::note[Prerequisites]
- **Node.js** 20+ (required for the installer)
- **Git** (recommended)
- **AI tool** (Claude Code, Cursor, or similar)
:::

## Steps

### 1. Run the Installer

```bash
npx skad-method install
```

:::tip[Bleeding edge]
To install the latest from the main branch (may be unstable):
```bash
npx github:skad-code-org/SKAD-METHOD install
```
:::

### 2. Choose Installation Location

The installer will ask where to install SKad files:

- Current directory (recommended for new projects if you created the directory yourself and ran from within the directory)
- Custom path

### 3. Select Your AI Tools

Pick which AI tools you use:

- Claude Code
- Cursor
- Others

Each tool has its own way of integrating skills. The installer creates tiny prompt files to activate workflows and agents — it just puts them where your tool expects to find them.

:::note[Enabling Skills]
Some platforms require skills to be explicitly enabled in settings before they appear. If you install SKad and don't see the skills, check your platform's settings or ask your AI assistant how to enable skills.
:::

### 4. Choose Modules

The installer shows available modules. Select whichever ones you need — most users just want **SKad Method** (the software development module).

### 5. Follow the Prompts

The installer guides you through the rest — custom content, settings, etc.

## What You Get

```text
your-project/
├── _skad/
│   ├── bmm/            # Your selected modules
│   │   └── config.yaml # Module settings (if you ever need to change them)
│   ├── core/           # Required core module
│   └── ...
├── _skad-output/       # Generated artifacts
├── .claude/            # Claude Code skills (if using Claude Code)
│   └── skills/
│       ├── skad-help/
│       ├── skad-persona/
│       └── ...
└── .cursor/            # Cursor skills (if using Cursor)
    └── skills/
        └── ...
```

## Verify Installation

Run `skad-help` to verify everything works and see what to do next.

**SKad-Help is your intelligent guide** that will:
- Confirm your installation is working
- Show what's available based on your installed modules
- Recommend your first step

You can also ask it questions:
```
skad-help I just installed, what should I do first?
skad-help What are my options for a SaaS project?
```

## Troubleshooting

**Installer throws an error** — Copy-paste the output into your AI assistant and let it figure it out.

**Installer worked but something doesn't work later** — Your AI needs SKad context to help. See [How to Get Answers About SKad](./get-answers-about-skad.md) for how to point your AI at the right sources.
