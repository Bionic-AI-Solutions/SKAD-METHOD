/**
 * SKAD-METHOD Standalone Installer
 *
 * Full install of SKAD into a target project without requiring npm publish.
 * Uses the local source and compiler — no glob/path-scurry dependency.
 *
 * Usage:
 *   node tools/install.js --directory /path/to/your-project
 *   node tools/install.js --directory /path/to/your-project --module bmm
 *   node tools/install.js --directory /path/to/your-project --action update
 *
 * Options:
 *   --directory  Target project directory (required)
 *   --module     Module to install: bmm (default), all
 *   --action     install (default) | update (preserves existing config)
 *   --name       Your name (used in config.yaml)
 *   --lang       Communication language (default: English)
 *   --output     Output folder relative to project root (default: _skad-output)
 *   --yes        Accept all defaults without prompting
 */

'use strict';

const path = require('node:path');
const fs = require('node:fs');
const readline = require('node:readline');

// ── Resolve repo root (this script lives in tools/) ──────────────────────────
const REPO_ROOT = path.resolve(__dirname, '..');
const SRC_BMM = path.join(REPO_ROOT, 'src', 'bmm');
const SRC_CORE = path.join(REPO_ROOT, 'src', 'core');
const UTILITY = path.join(REPO_ROOT, 'src', 'utility');

// ── Parse CLI args ────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
function arg(name, def) {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? def : args[i + 1];
}
function flag(name) {
  return args.includes(`--${name}`);
}

const TARGET = arg('directory', null);
const MODULE = arg('module', 'bmm');
const ACTION = arg('action', 'install');
const USER_NAME = arg('name', null);
const LANG = arg('lang', 'English');
const OUTPUT = arg('output', '_skad-output');
const YES = flag('yes');

if (!TARGET) {
  console.error('❌ --directory is required.\n   Usage: node tools/install.js --directory /path/to/project');
  process.exit(1);
}

const TARGET_DIR = path.resolve(TARGET);
const SKAD_DIR = path.join(TARGET_DIR, '_skad');
const CFG_DIR = path.join(SKAD_DIR, '_config');
const CLAUDE_DIR = path.join(TARGET_DIR, '.claude');
const SKILLS_DIR = path.join(CLAUDE_DIR, 'skills');

// ── Collectors for manifest generation ───────────────────────────────────────
const collectedAgents = [];
const collectedWorkflows = [];
const collectedTasks = [];
const collectedSkills = [];

// ── Utilities ─────────────────────────────────────────────────────────────────
function escapeCsv(value) {
  return `"${String(value ?? '').replaceAll('"', '""')}"`;
}

function copyDirSync(src, dest, { skipPatterns = [] } = {}) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (skipPatterns.some((p) => entry.name.match(p))) continue;
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath, { skipPatterns });
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function readFrontmatter(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const match = content.match(/^---\n([\s\S]*?)\n---/);
    if (!match) return {};
    const fm = {};
    for (const line of match[1].split('\n')) {
      const [k, ...v] = line.split(':');
      if (k && v.length > 0)
        fm[k.trim()] = v
          .join(':')
          .trim()
          .replaceAll(/^['"]|['"]$/g, '');
    }
    return fm;
  } catch {
    return {};
  }
}

function writeSkill(skillName, name, description, loaderLine) {
  const dir = path.join(SKILLS_DIR, skillName);
  fs.mkdirSync(dir, { recursive: true });
  const content = `---\nname: ${name}\ndescription: ${description}\n---\n\n${loaderLine}\n`;
  fs.writeFileSync(path.join(dir, 'SKILL.md'), content);
}

async function prompt(question) {
  if (YES) return '';
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

// ── Compile agent YAML → .md ──────────────────────────────────────────────────
async function compileAgentFile(yamlPath, destMdPath) {
  const { compileAgent } = require('./cli/lib/agent/compiler.js');
  const yamlContent = fs.readFileSync(yamlPath, 'utf8');
  const agentName = path.basename(yamlPath, '.agent.yaml');
  const relPath = path.relative(SKAD_DIR, destMdPath).replaceAll('\\', '/');

  const { xml } = await compileAgent(yamlContent, {}, agentName, relPath, {
    sourceDir: REPO_ROOT,
    utilityDir: UTILITY,
  });

  fs.mkdirSync(path.dirname(destMdPath), { recursive: true });
  fs.writeFileSync(destMdPath, xml);
  return agentName;
}

// ── Create .claude/skills entry for an agent ─────────────────────────────────
function installAgentSkill(agentName, title, description, moduleName) {
  const agentPath = `_skad/${moduleName}/agents/${agentName}.md`;
  const loaderLine = [
    "You must fully embody this agent's persona and follow all activation instructions exactly as specified.",
    'NEVER break character until given an exit command.',
    '',
    '<agent-activation CRITICAL="TRUE">',
    `1. LOAD the FULL agent file from {project-root}/${agentPath}`,
    '2. READ its entire contents - this contains the complete agent persona, menu, and instructions',
    '3. FOLLOW every step in the <activation> section precisely',
    '4. DISPLAY the welcome/greeting as instructed',
    '5. PRESENT the numbered menu',
    '6. WAIT for user input before proceeding',
    '</agent-activation>',
  ].join('\n');

  const skillName = moduleName === 'core' ? agentName : `skad-${agentName}`;
  writeSkill(skillName, `"${title || agentName}"`, `"${description || 'SKAD Agent'}"`, loaderLine);
  return skillName;
}

// ── Create .claude/skills entry for a workflow ────────────────────────────────
function installWorkflowSkill(skillName, name, description, workflowRelPath) {
  const loaderLine = `IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL {project-root}/_skad/${workflowRelPath}, READ its entire contents and follow its directions exactly!`;
  writeSkill(skillName, `"${name}"`, `"${description}"`, loaderLine);
}

// ── Create .claude/skills entry for a task ──────────────────────────────────
function installTaskSkill(skillName, description, taskRelPath) {
  const loaderLine = `IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL {project-root}/_skad/${taskRelPath}, READ its entire contents and follow its directions exactly!`;
  writeSkill(skillName, `"${skillName}"`, `"${description}"`, loaderLine);
}

// ── Parse a skad-skill-manifest.yaml with multiple entries ──────────────────
function parseManifestYaml(manifestPath) {
  const entries = [];
  const content = fs.readFileSync(manifestPath, 'utf8');
  let current = null;

  for (const line of content.split('\n')) {
    // Top-level key (filename: or single-line canonicalId:)
    const fileMatch = line.match(/^(\S+):$/);
    if (fileMatch && !line.startsWith(' ')) {
      if (current) entries.push(current);
      current = { file: fileMatch[1] };
      continue;
    }
    if (!current) {
      // Handle single-entry manifests (canonicalId: value on first line)
      const kvMatch = line.match(/^(\w[\w-]*):\s*"?(.+?)"?\s*$/);
      if (kvMatch) {
        if (!current) current = {};
        current[kvMatch[1]] = kvMatch[2];
      }
      continue;
    }
    const kvMatch = line.match(/^\s+(\w[\w-]*):\s*"?(.+?)"?\s*$/);
    if (kvMatch) {
      current[kvMatch[1]] = kvMatch[2];
    }
  }
  if (current) entries.push(current);
  return entries;
}

// ── Scan a module for workflow skill manifests ────────────────────────────────
function findWorkflowSkills(moduleDir, moduleRelPath) {
  const skills = [];
  function walk(dir, relDir) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      const rel = relDir ? `${relDir}/${entry.name}` : entry.name;
      if (entry.isDirectory()) {
        walk(full, rel);
      } else if (entry.name === 'skad-skill-manifest.yaml') {
        const manifest = {};
        for (const line of fs.readFileSync(full, 'utf8').split('\n')) {
          const [k, ...v] = line.split(':');
          if (k && v.length > 0)
            manifest[k.trim()] = v
              .join(':')
              .trim()
              .replaceAll(/^['"]|['"]$/g, '');
        }
        // Find the workflow.md in the same dir
        const workflowMd = path.join(path.dirname(full), 'workflow.md');
        if (fs.existsSync(workflowMd)) {
          const fm = readFrontmatter(workflowMd);
          skills.push({
            skillName: manifest.canonicalId || fm.name || path.basename(path.dirname(full)),
            name: fm.name || manifest.canonicalId,
            description: manifest.description || fm.description || '',
            workflowRelPath: `${moduleRelPath}/${rel.replace('skad-skill-manifest.yaml', 'workflow.md')}`,
          });
        }
      }
    }
  }
  walk(moduleDir, '');
  return skills;
}

// ── Generate _config directory and manifest CSVs ─────────────────────────────
function generateManifests() {
  fs.mkdirSync(CFG_DIR, { recursive: true });
  fs.mkdirSync(path.join(CFG_DIR, 'agents'), { recursive: true });
  fs.mkdirSync(path.join(CFG_DIR, 'custom'), { recursive: true });

  // agent-manifest.csv
  let agentCsv = 'name,displayName,title,icon,capabilities,role,identity,communicationStyle,principles,module,path,canonicalId\n';
  for (const a of collectedAgents) {
    agentCsv +=
      [
        escapeCsv(a.name),
        escapeCsv(a.displayName),
        escapeCsv(a.title),
        escapeCsv(a.icon),
        escapeCsv(a.capabilities),
        escapeCsv(a.role),
        escapeCsv(a.identity),
        escapeCsv(a.communicationStyle),
        escapeCsv(a.principles),
        escapeCsv(a.module),
        escapeCsv(a.path),
        escapeCsv(a.canonicalId),
      ].join(',') + '\n';
  }
  fs.writeFileSync(path.join(CFG_DIR, 'agent-manifest.csv'), agentCsv);

  // workflow-manifest.csv
  let wfCsv = 'name,description,module,path,canonicalId\n';
  for (const w of collectedWorkflows) {
    wfCsv +=
      [escapeCsv(w.name), escapeCsv(w.description), escapeCsv(w.module), escapeCsv(w.path), escapeCsv(w.canonicalId)].join(',') + '\n';
  }
  fs.writeFileSync(path.join(CFG_DIR, 'workflow-manifest.csv'), wfCsv);

  // task-manifest.csv
  let taskCsv = 'name,displayName,description,module,path,standalone,canonicalId\n';
  for (const t of collectedTasks) {
    taskCsv +=
      [
        escapeCsv(t.name),
        escapeCsv(t.displayName),
        escapeCsv(t.description),
        escapeCsv(t.module),
        escapeCsv(t.path),
        escapeCsv(t.standalone),
        escapeCsv(t.canonicalId),
      ].join(',') + '\n';
  }
  fs.writeFileSync(path.join(CFG_DIR, 'task-manifest.csv'), taskCsv);

  // skill-manifest.csv
  let skillCsv = 'canonicalId,name,description,module,path,install_to_skad\n';
  for (const s of collectedSkills) {
    skillCsv +=
      [
        escapeCsv(s.canonicalId),
        escapeCsv(s.name),
        escapeCsv(s.description),
        escapeCsv(s.module),
        escapeCsv(s.path),
        escapeCsv(s.install_to_skad),
      ].join(',') + '\n';
  }
  fs.writeFileSync(path.join(CFG_DIR, 'skill-manifest.csv'), skillCsv);
}

// ── Generate config.yaml for a module ────────────────────────────────────────
function generateConfigYaml(modulePath, moduleName, configValues) {
  const packageJson = require(path.join(REPO_ROOT, 'package.json'));
  const header = `# ${moduleName.toUpperCase()} Module Configuration\n# Generated by SKAD installer\n# Version: ${packageJson.version}\n# Date: ${new Date().toISOString()}\n\n`;

  const lines = [];
  for (const [key, value] of Object.entries(configValues)) {
    lines.push(`${key}: ${value}`);
  }

  const configPath = path.join(modulePath, 'config.yaml');
  fs.writeFileSync(configPath, header + lines.join('\n') + '\n');
  return configPath;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n🚀 SKAD-METHOD Installer');
  console.log(`   Source: ${REPO_ROOT}`);
  console.log(`   Target: ${TARGET_DIR}`);
  console.log(`   Action: ${ACTION}\n`);

  // Validate target
  if (!fs.existsSync(TARGET_DIR)) {
    fs.mkdirSync(TARGET_DIR, { recursive: true });
    console.log(`📁 Created project directory: ${TARGET_DIR}`);
  }

  const isUpdate = ACTION === 'update';
  const bmmConfigPath = path.join(SKAD_DIR, 'bmm', 'config.yaml');
  const hasExisting = fs.existsSync(bmmConfigPath);

  if (isUpdate && !hasExisting) {
    console.error('❌ --action update requires an existing installation. Run without --action first.');
    process.exit(1);
  }

  // ── Collect config values ──────────────────────────────────────────────────
  let userName = USER_NAME;
  let commLang = LANG;
  let outputFolder = OUTPUT;

  if (isUpdate) {
    // Preserve existing config values
    const existing = fs.readFileSync(bmmConfigPath, 'utf8');
    const nameMatch = existing.match(/^user_name:\s*(.+)$/m);
    userName = nameMatch ? nameMatch[1].trim() : 'Demo User';
    const langMatch = existing.match(/^communication_language:\s*(.+)$/m);
    commLang = langMatch ? langMatch[1].trim() : LANG;
    const outMatch = existing.match(/^output_folder:\s*(.+)$/m);
    outputFolder = outMatch ? outMatch[1].trim() : OUTPUT;
    console.log(`⏭️  Update mode: preserving existing config (user: ${userName})`);
  } else {
    if (!userName) {
      const ans = await prompt('Your name (for agents to use) [Demo User]: ');
      userName = ans || 'Demo User';
    }
    const langAns = await prompt(`Communication language [${LANG}]: `);
    commLang = langAns || LANG;
    const outAns = await prompt(`Output folder relative to project root [${OUTPUT}]: `);
    outputFolder = outAns || OUTPUT;
  }

  const projectName = path.basename(TARGET_DIR);
  const coreConfigValues = {
    project_name: projectName,
    user_name: userName,
    communication_language: commLang,
    document_output_language: commLang,
    user_skill_level: 'intermediate',
    output_folder: outputFolder,
    planning_artifacts: `./${outputFolder}/planning-artifacts`,
    implementation_artifacts: `./${outputFolder}/implementation-artifacts`,
    project_knowledge: './docs',
  };

  // ── Step 1: Copy source files ──────────────────────────────────────────────
  console.log('\n📦 Copying SKAD source files...');

  // Copy core
  if (fs.existsSync(SRC_CORE)) {
    copyDirSync(SRC_CORE, path.join(SKAD_DIR, 'core'), {
      skipPatterns: [/^module\.yaml$/, /\.agent\.yaml$/],
    });
    console.log('   ✅ core/');
  }

  // Copy bmm module (skip .agent.yaml — those get compiled separately)
  copyDirSync(SRC_BMM, path.join(SKAD_DIR, 'bmm'), {
    skipPatterns: [/\.agent\.yaml$/],
  });
  console.log('   ✅ bmm/');

  // ── Step 2: Write config.yaml for each module ──────────────────────────────
  console.log('\n⚙️  Generating config files...');

  // Core config
  generateConfigYaml(path.join(SKAD_DIR, 'core'), 'core', coreConfigValues);
  console.log('   ✅ core/config.yaml');

  // BMM config (core values + dev-tasks settings)
  if (isUpdate) {
    console.log('   ⏭️  bmm/config.yaml (preserved)');
  } else {
    const bmmConfigValues = {
      ...coreConfigValues,
      '\n# dev-tasks orchestrator settings': '',
      autonomy_mode: 'halt-after-story   # implement-only | halt-after-story | halt-on-high | full-hands-off',
      stall_warn_minutes: '10',
      stall_kill_minutes: '20',
    };
    // Write bmm config manually to avoid the comment key hack
    const packageJson = require(path.join(REPO_ROOT, 'package.json'));
    const bmmContent =
      [
        `# BMM Module Configuration`,
        `# Generated by SKAD installer`,
        `# Version: ${packageJson.version}`,
        `# Date: ${new Date().toISOString()}`,
        ``,
        `project_name: ${projectName}`,
        `user_name: ${userName}`,
        `communication_language: ${commLang}`,
        `document_output_language: ${commLang}`,
        `user_skill_level: intermediate`,
        `output_folder: ${outputFolder}`,
        `planning_artifacts: ./${outputFolder}/planning-artifacts`,
        `implementation_artifacts: ./${outputFolder}/implementation-artifacts`,
        `project_knowledge: ./docs`,
        ``,
        `# dev-tasks orchestrator settings`,
        `autonomy_mode: halt-after-story   # implement-only | halt-after-story | halt-on-high | full-hands-off`,
        `stall_warn_minutes: 10`,
        `stall_kill_minutes: 20`,
      ].join('\n') + '\n';
    fs.mkdirSync(path.dirname(bmmConfigPath), { recursive: true });
    fs.writeFileSync(bmmConfigPath, bmmContent);
    console.log('   ✅ bmm/config.yaml');
  }

  // ── Step 3: Compile BMM agents ─────────────────────────────────────────────
  console.log('\n🔧 Compiling agents...');
  const agentsDir = path.join(SRC_BMM, 'agents');
  const destAgentsDir = path.join(SKAD_DIR, 'bmm', 'agents');
  fs.mkdirSync(SKILLS_DIR, { recursive: true });

  // Parse the bmm agents manifest for canonicalIds
  const bmmAgentManifest = path.join(SRC_BMM, 'agents', 'skad-skill-manifest.yaml');
  const bmmAgentManifestEntries = fs.existsSync(bmmAgentManifest) ? parseManifestYaml(bmmAgentManifest) : [];
  const agentCanonicalMap = {};
  for (const entry of bmmAgentManifestEntries) {
    if (entry.file && entry.canonicalId) {
      const name = entry.file.replace('.agent.yaml', '');
      agentCanonicalMap[name] = entry.canonicalId;
    }
  }

  for (const entry of fs.readdirSync(agentsDir, { withFileTypes: true })) {
    if (!entry.name.endsWith('.agent.yaml')) continue;

    const yamlPath = path.join(agentsDir, entry.name);
    const agentName = entry.name.replace('.agent.yaml', '');
    const destMd = path.join(destAgentsDir, `${agentName}.md`);

    try {
      await compileAgentFile(yamlPath, destMd);

      const yaml = require('yaml');
      const parsed = yaml.parse(fs.readFileSync(yamlPath, 'utf8'));
      const meta = parsed?.agent?.metadata || {};
      const persona = parsed?.agent?.persona || {};
      const title = meta.name || agentName;
      const desc = `${meta.title || 'SKAD Agent'} — ${meta.capabilities || ''}`.trim().replace(/—\s*$/, '');
      const canonicalId = agentCanonicalMap[agentName] || `skad-${agentName}`;

      const skillName = installAgentSkill(agentName, title, desc, 'bmm');
      console.log(`   ✅ ${agentName}.md  →  .claude/skills/${skillName}/`);

      // Collect for manifest
      collectedAgents.push({
        name: agentName,
        displayName: meta.name || agentName,
        title: meta.title || '',
        icon: meta.icon || '',
        capabilities: meta.capabilities || '',
        role: persona.role || '',
        identity: persona.identity || '',
        communicationStyle: persona.communication_style || '',
        principles: String(persona.principles ?? '')
          .replaceAll('\n', ' ')
          .trim(),
        module: 'bmm',
        path: `bmm/agents/${agentName}.md`,
        canonicalId,
      });

      collectedSkills.push({
        canonicalId,
        name: title,
        description: desc,
        module: 'bmm',
        path: `bmm/agents/${agentName}.md`,
        install_to_skad: 'true',
      });
    } catch (error) {
      console.warn(`   ⚠️  Could not compile ${entry.name}: ${error.message}`);
    }
  }

  // ── Step 3b: Compile core agents ───────────────────────────────────────────
  const coreAgentsDir = path.join(SRC_CORE, 'agents');
  const destCoreAgentsDir = path.join(SKAD_DIR, 'core', 'agents');

  if (fs.existsSync(coreAgentsDir)) {
    for (const entry of fs.readdirSync(coreAgentsDir, { withFileTypes: true })) {
      if (!entry.name.endsWith('.agent.yaml')) continue;

      const yamlPath = path.join(coreAgentsDir, entry.name);
      const agentName = entry.name.replace('.agent.yaml', '');
      const destMd = path.join(destCoreAgentsDir, `${agentName}.md`);

      try {
        await compileAgentFile(yamlPath, destMd);

        const yaml = require('yaml');
        const parsed = yaml.parse(fs.readFileSync(yamlPath, 'utf8'));
        const meta = parsed?.agent?.metadata || {};
        const persona = parsed?.agent?.persona || {};
        const title = meta.name || agentName;
        const desc = `${meta.title || 'SKAD Agent'} — ${meta.capabilities || ''}`.trim().replace(/—\s*$/, '');

        const skillName = installAgentSkill(agentName, title, desc, 'core');
        console.log(`   ✅ ${agentName}.md  →  .claude/skills/${skillName}/`);

        collectedAgents.push({
          name: agentName,
          displayName: meta.name || agentName,
          title: meta.title || '',
          icon: meta.icon || '',
          capabilities: meta.capabilities || '',
          role: persona.role || '',
          identity: persona.identity || '',
          communicationStyle: persona.communication_style || '',
          principles: String(persona.principles ?? '')
            .replaceAll('\n', ' ')
            .trim(),
          module: 'core',
          path: `core/agents/${agentName}.md`,
          canonicalId: agentName,
        });

        collectedSkills.push({
          canonicalId: agentName,
          name: title,
          description: desc,
          module: 'core',
          path: `core/agents/${agentName}.md`,
          install_to_skad: 'true',
        });
      } catch (error) {
        console.warn(`   ⚠️  Could not compile ${entry.name}: ${error.message}`);
      }
    }
  }

  // ── Step 4: Install bmm workflow skills ─────────────────────────────────────
  console.log('\n🔗 Installing workflow skills...');
  const workflowSkills = findWorkflowSkills(path.join(SRC_BMM, 'workflows'), 'bmm/workflows');

  for (const skill of workflowSkills) {
    installWorkflowSkill(skill.skillName, skill.name, skill.description, skill.workflowRelPath);
    console.log(`   ✅ ${skill.skillName}  →  .claude/skills/${skill.skillName}/`);

    collectedWorkflows.push({
      name: skill.name,
      description: skill.description,
      module: 'bmm',
      path: skill.workflowRelPath,
      canonicalId: skill.skillName,
    });

    collectedSkills.push({
      canonicalId: skill.skillName,
      name: skill.name,
      description: skill.description,
      module: 'bmm',
      path: skill.workflowRelPath,
      install_to_skad: 'true',
    });
  }

  // ── Step 4b: Install core workflow skills ─────────────────────────────────
  const coreWorkflowSkills = findWorkflowSkills(path.join(SRC_CORE, 'workflows'), 'core/workflows');

  for (const skill of coreWorkflowSkills) {
    installWorkflowSkill(skill.skillName, skill.name, skill.description, skill.workflowRelPath);
    console.log(`   ✅ ${skill.skillName}  →  .claude/skills/${skill.skillName}/`);

    collectedWorkflows.push({
      name: skill.name,
      description: skill.description,
      module: 'core',
      path: skill.workflowRelPath,
      canonicalId: skill.skillName,
    });

    collectedSkills.push({
      canonicalId: skill.skillName,
      name: skill.name,
      description: skill.description,
      module: 'core',
      path: skill.workflowRelPath,
      install_to_skad: 'true',
    });
  }

  // ── Step 4c: Install core task skills ─────────────────────────────────────
  console.log('\n📋 Installing task skills...');
  const coreTaskManifest = path.join(SRC_CORE, 'tasks', 'skad-skill-manifest.yaml');
  if (fs.existsSync(coreTaskManifest)) {
    const tasks = parseManifestYaml(coreTaskManifest);
    for (const task of tasks) {
      if (!task.canonicalId) continue;
      installTaskSkill(task.canonicalId, task.description || '', `core/tasks/${task.file}`);
      console.log(`   ✅ ${task.canonicalId}  →  .claude/skills/${task.canonicalId}/`);

      collectedTasks.push({
        name: task.file ? task.file.replace(/\.\w+$/, '') : task.canonicalId,
        displayName: task.canonicalId,
        description: task.description || '',
        module: 'core',
        path: `core/tasks/${task.file || ''}`,
        standalone: 'true',
        canonicalId: task.canonicalId,
      });

      collectedSkills.push({
        canonicalId: task.canonicalId,
        name: task.canonicalId,
        description: task.description || '',
        module: 'core',
        path: `core/tasks/${task.file || ''}`,
        install_to_skad: 'true',
      });
    }
  }

  // Scan for task subdirectories with their own manifest + workflow.md
  const coreTasksDir = path.join(SRC_CORE, 'tasks');
  if (fs.existsSync(coreTasksDir)) {
    const taskSubdirSkills = findWorkflowSkills(coreTasksDir, 'core/tasks');
    for (const skill of taskSubdirSkills) {
      if (skill.workflowRelPath === 'core/tasks/workflow.md') continue;
      installWorkflowSkill(skill.skillName, skill.name, skill.description, skill.workflowRelPath);
      console.log(`   ✅ ${skill.skillName}  →  .claude/skills/${skill.skillName}/`);

      collectedTasks.push({
        name: skill.skillName,
        displayName: skill.name,
        description: skill.description,
        module: 'core',
        path: skill.workflowRelPath,
        standalone: 'true',
        canonicalId: skill.skillName,
      });

      collectedSkills.push({
        canonicalId: skill.skillName,
        name: skill.name,
        description: skill.description,
        module: 'core',
        path: skill.workflowRelPath,
        install_to_skad: 'true',
      });
    }
  }

  // ── Step 5: Generate _config manifests ─────────────────────────────────────
  console.log('\n📊 Generating manifests...');
  generateManifests();
  console.log(`   ✅ agent-manifest.csv    (${collectedAgents.length} agents)`);
  console.log(`   ✅ workflow-manifest.csv  (${collectedWorkflows.length} workflows)`);
  console.log(`   ✅ task-manifest.csv      (${collectedTasks.length} tasks)`);
  console.log(`   ✅ skill-manifest.csv     (${collectedSkills.length} skills)`);

  // ── Step 6: Create .claude/settings.local.json if missing ─────────────────
  const settingsPath = path.join(CLAUDE_DIR, 'settings.local.json');
  if (!fs.existsSync(settingsPath)) {
    fs.mkdirSync(CLAUDE_DIR, { recursive: true });
    fs.writeFileSync(settingsPath, JSON.stringify({ permissions: { allow: [], deny: [] } }, null, 2));
    console.log('\n⚙️  Created .claude/settings.local.json');
  }

  // ── Step 7: Create output directory ────────────────────────────────────────
  const outputDir = path.join(TARGET_DIR, outputFolder);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
    fs.mkdirSync(path.join(outputDir, 'planning-artifacts'), { recursive: true });
    fs.mkdirSync(path.join(outputDir, 'implementation-artifacts'), { recursive: true });
    console.log(`\n📁 Created output directory: ${outputFolder}/`);
  }

  // ── Done ───────────────────────────────────────────────────────────────────
  const totalSkills = fs.readdirSync(SKILLS_DIR).filter((f) => !f.startsWith('.')).length;
  console.log('\n✅ Installation complete!\n');
  console.log('   Project:    ' + TARGET_DIR);
  console.log('   Config:     _skad/core/config.yaml + _skad/bmm/config.yaml');
  console.log('   Manifests:  _skad/_config/ (4 CSV manifests)');
  console.log('   Skills:     .claude/skills/ (' + totalSkills + ' installed)');
  console.log('   Output:     ' + outputFolder + '/');
  console.log('');
  console.log('   Next steps:');
  console.log('   1. Open ' + TARGET_DIR + ' in Claude Code');
  console.log('   2. Type /skad-help   to get guidance on what to do next');
  console.log('   3. Type /skad-master to launch the orchestrator');
  console.log('   4. Type /skad-sm     to launch the Scrum Master agent');
  console.log('   5. Type /skad-dev    to launch the Developer agent');
  console.log('');
}

main().catch((error) => {
  console.error('\n❌ Install failed:', error.message);
  if (process.env.SKAD_DEBUG) console.error(error.stack);
  process.exit(1);
});
