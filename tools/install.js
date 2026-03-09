#!/usr/bin/env node
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
const SRC_BMM   = path.join(REPO_ROOT, 'src', 'bmm');
const SRC_CORE  = path.join(REPO_ROOT, 'src', 'core');
const UTILITY   = path.join(REPO_ROOT, 'src', 'utility');

// ── Parse CLI args ────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
function arg(name, def) {
  const i = args.indexOf(`--${name}`);
  return i !== -1 ? args[i + 1] : def;
}
function flag(name) { return args.includes(`--${name}`); }

const TARGET     = arg('directory', null);
const MODULE     = arg('module', 'bmm');
const ACTION     = arg('action', 'install');
const USER_NAME  = arg('name', null);
const LANG       = arg('lang', 'English');
const OUTPUT     = arg('output', '_skad-output');
const YES        = flag('yes');

if (!TARGET) {
  console.error('❌ --directory is required.\n   Usage: node tools/install.js --directory /path/to/project');
  process.exit(1);
}

const TARGET_DIR  = path.resolve(TARGET);
const SKAD_DIR    = path.join(TARGET_DIR, '_skad');
const CLAUDE_DIR  = path.join(TARGET_DIR, '.claude');
const SKILLS_DIR  = path.join(CLAUDE_DIR, 'skills');

// ── Utilities ─────────────────────────────────────────────────────────────────
function copyDirSync(src, dest, { skipPatterns = [] } = {}) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (skipPatterns.some(p => entry.name.match(p))) continue;
    const srcPath  = path.join(src, entry.name);
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
      if (k && v.length) fm[k.trim()] = v.join(':').trim().replace(/^['"]|['"]$/g, '');
    }
    return fm;
  } catch { return {}; }
}

function writeSkill(skillName, name, description, loaderLine) {
  const dir = path.join(SKILLS_DIR, skillName);
  fs.mkdirSync(dir, { recursive: true });
  const content = `---\nname: ${name}\ndescription: ${description}\n---\n\n${loaderLine}\n`;
  fs.writeFileSync(path.join(dir, 'SKILL.md'), content);
}

async function prompt(question) {
  if (YES) return '';
  return new Promise(resolve => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, answer => { rl.close(); resolve(answer.trim()); });
  });
}

// ── Compile agent YAML → .md ──────────────────────────────────────────────────
async function compileAgentFile(yamlPath, destMdPath) {
  const { compileAgent } = require('./cli/lib/agent/compiler.js');
  const yamlContent = fs.readFileSync(yamlPath, 'utf8');
  const agentName   = path.basename(yamlPath, '.agent.yaml');
  const relPath     = path.relative(SKAD_DIR, destMdPath).replace(/\\/g, '/');

  const { xml } = await compileAgent(yamlContent, {}, agentName, relPath, {
    sourceDir: REPO_ROOT,
    utilityDir: UTILITY,
  });

  fs.mkdirSync(path.dirname(destMdPath), { recursive: true });
  fs.writeFileSync(destMdPath, xml);
  return agentName;
}

// ── Create .claude/skills entry for an agent ─────────────────────────────────
function installAgentSkill(agentName, title, description) {
  const loaderLine = [
    'You must fully embody this agent\'s persona and follow all activation instructions exactly as specified.',
    'NEVER break character until given an exit command.',
    '',
    '<agent-activation CRITICAL="TRUE">',
    '1. LOAD the FULL agent file from {project-root}/_skad/bmm/agents/' + agentName + '.md',
    '2. READ its entire contents - this contains the complete agent persona, menu, and instructions',
    '3. FOLLOW every step in the <activation> section precisely',
    '4. DISPLAY the welcome/greeting as instructed',
    '5. PRESENT the numbered menu',
    '6. WAIT for user input before proceeding',
    '</agent-activation>',
  ].join('\n');

  writeSkill(
    `skad-${agentName}`,
    `"${title || agentName}"`,
    `"${description || 'SKAD Agent'}"`,
    loaderLine
  );
}

// ── Create .claude/skills entry for a workflow ────────────────────────────────
function installWorkflowSkill(skillName, name, description, workflowRelPath) {
  const loaderLine = `IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL {project-root}/_skad/${workflowRelPath}, READ its entire contents and follow its directions exactly!`;
  writeSkill(skillName, `"${name}"`, `"${description}"`, loaderLine);
}

// ── Scan a module for workflow skill manifests ────────────────────────────────
function findWorkflowSkills(moduleDir, moduleRelPath) {
  const skills = [];
  function walk(dir, relDir) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      const rel  = relDir ? `${relDir}/${entry.name}` : entry.name;
      if (entry.isDirectory()) {
        walk(full, rel);
      } else if (entry.name === 'skad-skill-manifest.yaml') {
        const manifest = {};
        for (const line of fs.readFileSync(full, 'utf8').split('\n')) {
          const [k, ...v] = line.split(':');
          if (k && v.length) manifest[k.trim()] = v.join(':').trim().replace(/^['"]|['"]$/g, '');
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
  const configPath = path.join(SKAD_DIR, 'bmm', 'config.yaml');
  const hasExisting = fs.existsSync(configPath);

  if (isUpdate && !hasExisting) {
    console.error('❌ --action update requires an existing installation. Run without --action first.');
    process.exit(1);
  }

  // ── Collect config values ──────────────────────────────────────────────────
  let userName = USER_NAME;
  let commLang = LANG;
  let outputFolder = OUTPUT;

  if (!isUpdate) {
    if (!userName) {
      const ans = await prompt('Your name (for agents to use) [Demo User]: ');
      userName = ans || 'Demo User';
    }
    const langAns = await prompt(`Communication language [${LANG}]: `);
    commLang = langAns || LANG;
    const outAns = await prompt(`Output folder relative to project root [${OUTPUT}]: `);
    outputFolder = outAns || OUTPUT;
  } else {
    // Preserve existing config values
    const existing = fs.readFileSync(configPath, 'utf8');
    const nameMatch = existing.match(/^user_name:\s*(.+)$/m);
    userName = nameMatch ? nameMatch[1].trim() : 'Demo User';
    console.log(`⏭️  Update mode: preserving existing config (user: ${userName})`);
  }

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

  // ── Step 2: Write config.yaml ──────────────────────────────────────────────
  if (!isUpdate) {
    const projectName = path.basename(TARGET_DIR);
    const configContent = [
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
    ].join('\n');

    fs.mkdirSync(path.dirname(configPath), { recursive: true });
    fs.writeFileSync(configPath, configContent);
    console.log('\n⚙️  Created config.yaml');
  }

  // ── Step 3: Compile agents ─────────────────────────────────────────────────
  console.log('\n🔧 Compiling agents...');
  const agentsDir = path.join(SRC_BMM, 'agents');
  const destAgentsDir = path.join(SKAD_DIR, 'bmm', 'agents');
  fs.mkdirSync(SKILLS_DIR, { recursive: true });

  for (const entry of fs.readdirSync(agentsDir, { withFileTypes: true })) {
    if (!entry.name.endsWith('.agent.yaml')) continue;

    const yamlPath  = path.join(agentsDir, entry.name);
    const agentName = entry.name.replace('.agent.yaml', '');
    const destMd    = path.join(destAgentsDir, `${agentName}.md`);

    try {
      await compileAgentFile(yamlPath, destMd);

      // Read metadata for the skill entry
      const yaml = require('yaml');
      const parsed = yaml.parse(fs.readFileSync(yamlPath, 'utf8'));
      const meta   = parsed?.agent?.metadata || {};
      const title  = meta.name || agentName;
      const desc   = `${meta.title || 'SKAD Agent'} — ${meta.capabilities || ''}`.trim().replace(/—\s*$/, '');

      installAgentSkill(agentName, title, desc);
      console.log(`   ✅ ${agentName}.md  →  .claude/skills/skad-${agentName}/`);
    } catch (err) {
      console.warn(`   ⚠️  Could not compile ${entry.name}: ${err.message}`);
    }
  }

  // ── Step 4: Install workflow skills ───────────────────────────────────────
  console.log('\n🔗 Installing workflow skills...');
  const workflowSkills = findWorkflowSkills(
    path.join(SRC_BMM, 'workflows'),
    'bmm/workflows'
  );

  for (const skill of workflowSkills) {
    installWorkflowSkill(skill.skillName, skill.name, skill.description, skill.workflowRelPath);
    console.log(`   ✅ ${skill.skillName}  →  .claude/skills/${skill.skillName}/`);
  }

  // ── Step 5: Create .claude/settings.local.json if missing ─────────────────
  const settingsPath = path.join(CLAUDE_DIR, 'settings.local.json');
  if (!fs.existsSync(settingsPath)) {
    fs.mkdirSync(CLAUDE_DIR, { recursive: true });
    fs.writeFileSync(settingsPath, JSON.stringify({ permissions: { allow: [], deny: [] } }, null, 2));
    console.log('\n⚙️  Created .claude/settings.local.json');
  }

  // ── Done ───────────────────────────────────────────────────────────────────
  console.log('\n✅ Installation complete!\n');
  console.log('   Project:    ' + TARGET_DIR);
  console.log('   Config:     ' + path.relative(TARGET_DIR, configPath));
  console.log('   Skills:     .claude/skills/ (' + fs.readdirSync(SKILLS_DIR).length + ' installed)');
  console.log('');
  console.log('   Next steps:');
  console.log('   1. Open ' + TARGET_DIR + ' in Claude Code');
  console.log('   2. Type /skad-sm  to launch the Scrum Master agent');
  console.log('   3. Type /skad-dev to launch the Developer agent (includes [DT] Dev Tasks)');
  console.log('');
}

main().catch(err => {
  console.error('\n❌ Install failed:', err.message);
  if (process.env.SKAD_DEBUG) console.error(err.stack);
  process.exit(1);
});
