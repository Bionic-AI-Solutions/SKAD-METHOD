---
title: Non-Interactive Installation
description: Install SKAD using command-line flags for CI/CD pipelines and automated deployments
sidebar:
  order: 2
---

Use command-line flags to install SKAD non-interactively. This is useful for:

## When to Use This

- Automated deployments and CI/CD pipelines
- Scripted installations
- Batch installations across multiple projects
- Quick installations with known configurations

:::note[Prerequisites]
Requires [Node.js](https://nodejs.org) v20+ and `npx` (included with npm).
:::

## Available Flags

### Installation Options

| Flag | Description | Example |
|------|-------------|---------|
| `--directory <path>` | Installation directory | `--directory ~/projects/myapp` |
| `--modules <modules>` | Comma-separated module IDs | `--modules skm,bmb` |
| `--tools <tools>` | Comma-separated tool/IDE IDs (use `none` to skip) | `--tools claude-code,cursor` or `--tools none` |
| `--custom-content <paths>` | Comma-separated paths to custom modules | `--custom-content ~/my-module,~/another-module` |
| `--action <type>` | Action for existing installations: `install` (default), `update`, `quick-update`, or `compile-agents` | `--action quick-update` |

### Core Configuration

| Flag | Description | Default |
|------|-------------|---------|
| `--user-name <name>` | Name for agents to use | System username |
| `--communication-language <lang>` | Agent communication language | English |
| `--document-output-language <lang>` | Document output language | English |
| `--output-folder <path>` | Output folder path | _skad-output |

### Other Options

| Flag | Description |
|------|-------------|
| `-y, --yes` | Accept all defaults and skip prompts |
| `-d, --debug` | Enable debug output for manifest generation |

## Module IDs

Available module IDs for the `--modules` flag:

- `skm` — SKAD Method Master
- `bmb` — SKAD Builder

Check the [SKAD registry](https://github.com/skad-code-org) for available external modules.

## Tool/IDE IDs

Available tool IDs for the `--tools` flag:

**Preferred:** `claude-code`, `cursor`, `windsurf`

Run `npx skad-method install` interactively once to see the full current list of supported tools, or check the [platform codes configuration](https://github.com/skad-code-org/SKAD-METHOD/blob/main/tools/cli/installers/lib/ide/platform-codes.yaml).

## Installation Modes

| Mode | Description | Example |
|------|-------------|---------|
| Fully non-interactive | Provide all flags to skip all prompts | `npx skad-method install --directory . --modules skm --tools claude-code --yes` |
| Semi-interactive | Provide some flags; SKAD prompts for the rest | `npx skad-method install --directory . --modules skm` |
| Defaults only | Accept all defaults with `-y` | `npx skad-method install --yes` |
| Without tools | Skip tool/IDE configuration | `npx skad-method install --modules skm --tools none` |

## Examples

### CI/CD Pipeline Installation

```bash
#!/bin/bash
# install-skad.sh

npx skad-method install \
  --directory "${GITHUB_WORKSPACE}" \
  --modules skm \
  --tools claude-code \
  --user-name "CI Bot" \
  --communication-language English \
  --document-output-language English \
  --output-folder _skad-output \
  --yes
```

### Update Existing Installation

```bash
npx skad-method install \
  --directory ~/projects/myapp \
  --action update \
  --modules skm,bmb,custom-module
```

### Quick Update (Preserve Settings)

```bash
npx skad-method install \
  --directory ~/projects/myapp \
  --action quick-update
```

### Installation with Custom Content

```bash
npx skad-method install \
  --directory ~/projects/myapp \
  --modules skm \
  --custom-content ~/my-custom-module,~/another-module \
  --tools claude-code
```

## What You Get

- A fully configured `_skad/` directory in your project
- Compiled agents and workflows for your selected modules and tools
- A `_skad-output/` folder for generated artifacts

## Validation and Error Handling

SKAD validates all provided flags:

- **Directory** — Must be a valid path with write permissions
- **Modules** — Warns about invalid module IDs (but won't fail)
- **Tools** — Warns about invalid tool IDs (but won't fail)
- **Custom Content** — Each path must contain a valid `module.yaml` file
- **Action** — Must be one of: `install`, `update`, `quick-update`, `compile-agents`

Invalid values will either:
1. Show an error and exit (for critical options like directory)
2. Show a warning and skip (for optional items like custom content)
3. Fall back to interactive prompts (for missing required values)

:::tip[Best Practices]
- Use absolute paths for `--directory` to avoid ambiguity
- Test flags locally before using in CI/CD pipelines
- Combine with `-y` for truly unattended installations
- Use `--debug` if you encounter issues during installation
:::

## Troubleshooting

### Installation fails with "Invalid directory"

- The directory path must exist (or its parent must exist)
- You need write permissions
- The path must be absolute or correctly relative to the current directory

### Module not found

- Verify the module ID is correct
- External modules must be available in the registry

### Custom content path invalid

Ensure each custom content path:
- Points to a directory
- Contains a `module.yaml` file in the root
- Has a `code` field in the `module.yaml`

:::note[Still stuck?]
Run with `--debug` for detailed output, try interactive mode to isolate the issue, or report at <https://github.com/skad-code-org/SKAD-METHOD/issues>.
:::
