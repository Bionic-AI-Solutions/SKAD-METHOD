// Extracts the next incomplete task from a BMAD story file's Ralph Tasks JSON.
// Usage: node scripts/ralph-extract-task.js <story_file_path>
// Output: JSON with task details, or {"done": true} if all tasks pass.

const { readFileSync } = require('node:fs');

const storyFile = process.argv[2];
if (!storyFile) {
  console.error('Usage: node scripts/ralph-extract-task.js <story_file_path>');
  process.exit(1);
}

const content = readFileSync(storyFile, 'utf-8');

// Extract Ralph Tasks JSON block
const jsonMatch = content.match(/## Ralph Tasks JSON[\s\S]*?```json\n([\s\S]*?)\n```/);
if (!jsonMatch) {
  console.error('No Ralph Tasks JSON found in story file');
  process.exit(1);
}

let tasks;
try {
  tasks = JSON.parse(jsonMatch[1]);
} catch (error) {
  console.error('Failed to parse Ralph Tasks JSON:', error.message);
  process.exit(1);
}

// Find first task where passes === false
const nextTask = tasks.find((t) => t.passes === false);

if (nextTask) {
  const completedCount = tasks.filter((t) => t.passes === true).length;
  console.log(
    JSON.stringify({
      done: false,
      taskId: nextTask.id,
      title: nextTask.title,
      steps: nextTask.steps || [],
      acceptanceCriteria: nextTask.acceptanceCriteria || [],
      checkCommands: nextTask.checkCommands || [],
      completedCount,
      totalTasks: tasks.length,
    }),
  );
} else {
  // All tasks pass
  console.log(JSON.stringify({ done: true, totalTasks: tasks.length }));
}
