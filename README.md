![SKad Method](banner-skad-method.png)

[![Version](https://img.shields.io/npm/v/skad-method?color=blue&label=version)](https://www.npmjs.com/package/skad-method)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Node.js Version](https://img.shields.io/badge/node-%3E%3D20.0.0-brightgreen)](https://nodejs.org)
[![Discord](https://img.shields.io/badge/Discord-Join%20Community-7289da?logo=discord&logoColor=white)](https://discord.gg/gk8jAdXWmj)

**Build More Architect Dreams** — An AI-driven agile development module for the SKad Method Module Ecosystem, the best and most comprehensive Agile AI Driven Development framework that has true scale-adaptive intelligence that adjusts from bug fixes to enterprise systems.

**100% free and open source.** No paywalls. No gated content. No gated Discord. We believe in empowering everyone, not just those who can pay for a gated community or courses.

## Why the SKad Method?

Traditional AI tools do the thinking for you, producing average results. SKad agents and facilitated workflows act as expert collaborators who guide you through a structured process to bring out your best thinking in partnership with the AI.

- **AI Intelligent Help** — Ask `/skad-help` anytime for guidance on what's next
- **Scale-Domain-Adaptive** — Automatically adjusts planning depth based on project complexity
- **Structured Workflows** — Grounded in agile best practices across analysis, planning, architecture, and implementationd
- **Specialized Agents** — 12+ domain experts (PM, Architect, Developer, UX, Scrum Master, and more)
- **Party Mode** — Bring multiple agent personas into one session to collaborate and discuss
- **Complete Lifecycle** — From brainstorming to deployment

[Learn more at **docs.skad-method.org**](https://docs.skad-method.org)

---

## 🚀 What's Next for SKad?

**V6 is here and we're just getting started!** The SKad Method is evolving rapidly with optimizations including Cross Platform Agent Team and Sub Agent inclusion, Skills Architecture, SKad Builder v1, Dev Loop Automation, and so much more in the works.

**[📍 Check out the complete Roadmap →](https://docs.skad-method.org/roadmap/)**

---

## Quick Start

**Prerequisites**: [Node.js](https://nodejs.org) v20+


### Installing from Source (Private / Air-Gapped Environments)

If you are working from a private fork or an environment without npm access, use the standalone installer that ships with this repo. It performs the full installation — agent compilation, skill registration, and config setup — directly from the local source:

```bash
# Clone the repo first
git clone <your-private-repo-url> skad-method
cd skad-method
npm install

# Install into a new project
node tools/install.js --directory /path/to/your-project

# Silent install with defaults (useful for scripts)
node tools/install.js --directory /path/to/your-project --yes --name "Your Name"

# Update an existing installation (preserves config.yaml)
node tools/install.js --directory /path/to/your-project --action update
```

**Options:**

| Flag | Description | Default |
|------|-------------|---------|
| `--directory` | Target project directory (required) | — |
| `--action` | `install` or `update` | `install` |
| `--name` | Your name for agents to use | prompted |
| `--lang` | Communication language | `English` |
| `--output` | Output folder relative to project root | `_skad-output` |
| `--yes` | Accept all defaults, skip prompts | off |

To patch an **already-installed** project with only the new `dev-tasks` workflow (without a full reinstall):

```bash
bash tools/patch-install-dev-tasks.sh /path/to/your-project
```

> **Not sure what to do?** Run `/skad-help` — it tells you exactly what's next and what's optional. You can also ask questions like `/skad-help I just finished the architecture, what do I do next?`

## Modules

SKad Method extends with official modules for specialized domains. Available during installation or anytime after.

| Module                                                                                                            | Purpose                                           |
| ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| **[SKad Method (BMM)](https://github.com/Bionic-AI-Solutions/SKAD-METHOD)**                                             | Core framework with 34+ workflows                 |
| **[SKad Builder (BMB)](https://github.com/Bionic-AI-Solutions/skad-builder)**                                           | Create custom SKad agents and workflows           |
| **[Test Architect (TEA)](https://github.com/Bionic-AI-Solutions/skad-method-test-architecture-enterprise)**             | Risk-based test strategy and automation           |
| **[Game Dev Studio (BMGD)](https://github.com/Bionic-AI-Solutions/skad-module-game-dev-studio)**                        | Game development workflows (Unity, Unreal, Godot) |
| **[Creative Intelligence Suite (CIS)](https://github.com/Bionic-AI-Solutions/skad-module-creative-intelligence-suite)** | Innovation, brainstorming, design thinking        |

## Documentation

[SKad Method Docs Site](https://docs.skad-method.org) — Tutorials, guides, concepts, and reference

**Quick links:**
- [Getting Started Tutorial](https://docs.skad-method.org/tutorials/getting-started/)
- [Upgrading from Previous Versions](https://docs.skad-method.org/how-to/upgrade-to-v6/)
- [Test Architect Documentation](https://Bionic-AI-Solutions.github.io/skad-method-test-architecture-enterprise/)


## Support SKad

SKad is free for everyone — and always will be. If you'd like to support development:

- ⭐ Please click the star project icon near the top right of this page
- 🏢 Corporate sponsorship — DM on Discord
- 🎤 Speaking & Media — Available for conferences, podcasts, interviews (BM on Discord)


## License

MIT License — see [LICENSE](LICENSE) for details.

---

