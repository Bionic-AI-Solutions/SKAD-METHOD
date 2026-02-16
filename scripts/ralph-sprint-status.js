// Sprint-status.yaml parser for Ralph autonomous loop.
// Parses the flat key:value YAML format used by sprint-status.yaml.
//
// Operations:
//   next-story [yaml_path]     — Find first in-progress or ready-for-dev story
//   epic-stories <epicNum> [yaml_path] — List all stories in an epic with statuses
//   update-status <key> <newStatus> [yaml_path] — Update a status entry in the YAML
//   task-summary <story_file>  — Parse Ralph Tasks JSON and return task counts
//
// Output: JSON to stdout

const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');

const DEFAULT_YAML_PATH = '_bmad-output/implementation-artifacts/sprint-status.yaml';
const STORY_DIR = '_bmad-output/implementation-artifacts';

// Parse sprint-status.yaml into a map of key → status
function parseSprintStatus(yamlPath) {
  const content = readFileSync(yamlPath, 'utf-8');
  const entries = [];

  for (const line of content.split('\n')) {
    // Skip comments, blank lines, non-indented lines (top-level keys like "generated:")
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    // Match "  key: value" pattern (indented under development_status:)
    const match = trimmed.match(/^([\w-]+):\s*(.+)$/);
    if (!match) continue;

    const [, key, value] = match;
    // Skip top-level metadata keys
    if (['generated', 'project', 'project_key', 'tracking_system', 'story_location', 'development_status'].includes(key)) continue;

    entries.push({ key, status: value.trim() });
  }

  return entries;
}

// Check if a key is a story key (e.g., "2-3-hybrid-intent-router")
function isStoryKey(key) {
  return /^\d+-\d+-/.test(key) && !key.includes('retrospective');
}

// Check if a key is an epic key (e.g., "epic-2")
function isEpicKey(key) {
  return /^epic-\d+$/.test(key);
}

// Extract epic number from a story key
function epicNumFromKey(key) {
  const match = key.match(/^(\d+)-/);
  return match ? parseInt(match[1], 10) : null;
}

// Extract story number from a story key
function storyNumFromKey(key) {
  const match = key.match(/^\d+-(\d+)-/);
  return match ? parseInt(match[1], 10) : null;
}

// Operation: next-story
// Find the first story that needs work (in-progress first, then ready-for-dev)
function nextStory(yamlPath) {
  const entries = parseSprintStatus(yamlPath);
  const stories = entries.filter((e) => isStoryKey(e.key));

  // Priority 1: in-progress (resume interrupted work)
  const inProgress = stories.find((s) => s.status === 'in-progress');
  if (inProgress) {
    const filePath = `${STORY_DIR}/${inProgress.key}.md`;
    return {
      done: false,
      storyKey: inProgress.key,
      status: inProgress.status,
      epicNum: epicNumFromKey(inProgress.key),
      storyNum: storyNumFromKey(inProgress.key),
      filePath,
    };
  }

  // Priority 2: ready-for-dev (start new)
  const readyForDev = stories.find((s) => s.status === 'ready-for-dev');
  if (readyForDev) {
    const filePath = `${STORY_DIR}/${readyForDev.key}.md`;
    return {
      done: false,
      storyKey: readyForDev.key,
      status: readyForDev.status,
      epicNum: epicNumFromKey(readyForDev.key),
      storyNum: storyNumFromKey(readyForDev.key),
      filePath,
    };
  }

  // Priority 3: backlog (need CS first)
  const backlog = stories.find((s) => s.status === 'backlog');
  if (backlog) {
    const filePath = `${STORY_DIR}/${backlog.key}.md`;
    return {
      done: false,
      needsCS: true,
      storyKey: backlog.key,
      status: backlog.status,
      epicNum: epicNumFromKey(backlog.key),
      storyNum: storyNumFromKey(backlog.key),
      filePath,
    };
  }

  // All stories are done or review
  return { done: true };
}

// Operation: epic-stories
// List all stories in an epic with their statuses
function epicStories(epicNum, yamlPath) {
  const entries = parseSprintStatus(yamlPath);
  const prefix = `${epicNum}-`;

  const stories = entries
    .filter((e) => isStoryKey(e.key) && e.key.startsWith(prefix))
    .map((e) => ({
      key: e.key,
      status: e.status,
      storyNum: storyNumFromKey(e.key),
    }));

  const epicEntry = entries.find((e) => e.key === `epic-${epicNum}`);
  const epicStatus = epicEntry ? epicEntry.status : 'unknown';

  const allDone = stories.length > 0 && stories.every((s) => s.status === 'done');

  return {
    epicNum: parseInt(epicNum, 10),
    epicStatus,
    allDone,
    stories,
  };
}

// Operation: update-status
// Update a key's status in sprint-status.yaml (preserves comments and structure)
function updateStatus(key, newStatus, yamlPath) {
  const lines = readFileSync(yamlPath, 'utf-8').split('\n');
  let updated = false;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    const match = trimmed.match(/^([\w-]+):\s*(.+)$/);
    if (match && match[1] === key) {
      // Preserve indentation
      const indent = lines[i].match(/^(\s*)/)[1];
      lines[i] = `${indent}${key}: ${newStatus}`;
      updated = true;
      break;
    }
  }

  if (!updated) {
    console.error(JSON.stringify({ error: `Key '${key}' not found in sprint-status.yaml` }));
    process.exit(1);
  }

  writeFileSync(yamlPath, lines.join('\n'));
  return { success: true, key, oldStatus: 'unknown', newStatus };
}

// Operation: task-summary
// Parse Ralph Tasks JSON from a story file and return counts
function taskSummary(storyFile) {
  const content = readFileSync(storyFile, 'utf-8');
  const jsonMatch = content.match(/## Ralph Tasks JSON\s*\n\s*```json\n([\s\S]*?)\n```/);

  if (!jsonMatch) {
    return { totalTasks: 0, passed: 0, failed: 0, tasks: [] };
  }

  let tasks;
  try {
    tasks = JSON.parse(jsonMatch[1]);
  } catch {
    return { totalTasks: 0, passed: 0, failed: 0, tasks: [] };
  }

  const passed = tasks.filter((t) => t.passes === true).length;
  const failed = tasks.filter((t) => t.passes === false).length;

  return {
    totalTasks: tasks.length,
    passed,
    failed,
    tasks: tasks.map((t) => ({
      id: t.id,
      title: t.title,
      passes: t.passes,
    })),
  };
}

// Operation: progress-report
// Generate markdown progress report body from sprint-status + story task data
function progressReport(yamlPath, activeStoryKey) {
  const entries = parseSprintStatus(yamlPath);

  // Group by epic
  const epics = {};
  for (const e of entries) {
    if (isEpicKey(e.key)) {
      const num = e.key.match(/^epic-(\d+)$/)[1];
      if (epics[num]) {
        epics[num].status = e.status;
      } else {
        epics[num] = { status: e.status, stories: [] };
      }
    } else if (isStoryKey(e.key)) {
      const num = String(epicNumFromKey(e.key));
      if (!epics[num]) epics[num] = { status: 'unknown', stories: [] };

      // Get task summary if story file exists
      let taskInfo = '--';
      const storyFilePath = resolve(`${STORY_DIR}/${e.key}.md`);
      try {
        const summary = taskSummary(storyFilePath);
        if (summary.totalTasks > 0) {
          taskInfo = `${summary.passed}/${summary.totalTasks} passed`;
        }
      } catch {
        // File doesn't exist or can't be parsed
      }

      const isActive = e.key === activeStoryKey;
      epics[num].stories.push({
        key: e.key,
        status: e.status,
        taskInfo,
        isActive,
      });
    }
  }

  // Render markdown
  let out = '';
  const epicNums = Object.keys(epics).sort((a, b) => parseInt(a) - parseInt(b));
  for (const num of epicNums) {
    const epic = epics[num];
    if (epic.stories.length === 0) continue;
    out += `### Epic ${num} (${epic.status})\n\n`;
    out += '| Story | Status | Tasks |\n';
    out += '|-------|--------|-------|\n';
    for (const s of epic.stories) {
      const b = s.isActive ? '**' : '';
      out += `| ${b}${s.key}${b} | ${b}${s.status}${b} | ${b}${s.taskInfo}${b} |\n`;
    }
    out += '\n';
  }
  return out;
}

// CLI
const operation = process.argv[2];

if (!operation) {
  console.error('Usage: node ralph-sprint-status.js <operation> [args]');
  console.error('Operations: next-story, epic-stories <epicNum>, update-status <key> <newStatus>, task-summary <storyFile>');
  process.exit(1);
}

switch (operation) {
  case 'next-story': {
    const yamlPath = resolve(process.argv[3] || DEFAULT_YAML_PATH);
    console.log(JSON.stringify(nextStory(yamlPath)));
    break;
  }
  case 'epic-stories': {
    const epicNum = process.argv[3];
    if (!epicNum) {
      console.error('Usage: node ralph-sprint-status.js epic-stories <epicNum> [yaml_path]');
      process.exit(1);
    }
    const yamlPath = resolve(process.argv[4] || DEFAULT_YAML_PATH);
    console.log(JSON.stringify(epicStories(epicNum, yamlPath)));
    break;
  }
  case 'update-status': {
    const key = process.argv[3];
    const newStatus = process.argv[4];
    if (!key || !newStatus) {
      console.error('Usage: node ralph-sprint-status.js update-status <key> <newStatus> [yaml_path]');
      process.exit(1);
    }
    const yamlPath = resolve(process.argv[5] || DEFAULT_YAML_PATH);
    console.log(JSON.stringify(updateStatus(key, newStatus, yamlPath)));
    break;
  }
  case 'task-summary': {
    const storyFile = process.argv[3];
    if (!storyFile) {
      console.error('Usage: node ralph-sprint-status.js task-summary <storyFile>');
      process.exit(1);
    }
    console.log(JSON.stringify(taskSummary(resolve(storyFile))));
    break;
  }
  case 'progress-report': {
    const activeKey = process.argv[3] || '';
    const yamlPath = resolve(process.argv[4] || DEFAULT_YAML_PATH);
    console.log(progressReport(yamlPath, activeKey));
    break;
  }
  default: {
    console.error(`Unknown operation: ${operation}`);
    process.exit(1);
  }
}
