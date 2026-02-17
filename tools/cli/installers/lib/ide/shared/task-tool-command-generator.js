const path = require('node:path');
const fs = require('fs-extra');
const csv = require('csv-parse/sync');
const { toColonName, toColonPath, toDashPath, SKAD_FOLDER_NAME } = require('./path-utils');

/**
 * Generates command files for standalone tasks and tools
 */
class TaskToolCommandGenerator {
  /**
   * @param {string} skadFolderName - Name of the SKAD folder for template rendering (default: '_skad')
   * Note: This parameter is accepted for API consistency with AgentCommandGenerator and
   * WorkflowCommandGenerator, but is not used for path stripping. The manifest always stores
   * filesystem paths with '_skad/' prefix (the actual folder name), while skadFolderName is
   * used for template placeholder rendering ({{skadFolderName}}).
   */
  constructor(skadFolderName = SKAD_FOLDER_NAME) {
    this.skadFolderName = skadFolderName;
  }

  /**
   * Collect task and tool artifacts for IDE installation
   * @param {string} skadDir - SKAD installation directory
   * @returns {Promise<Object>} Artifacts array with metadata
   */
  async collectTaskToolArtifacts(skadDir) {
    const tasks = await this.loadTaskManifest(skadDir);
    const tools = await this.loadToolManifest(skadDir);

    // All tasks/tools in manifest are standalone (internal=true items are filtered during manifest generation)
    const artifacts = [];
    const skadPrefix = `${SKAD_FOLDER_NAME}/`;

    // Collect task artifacts
    for (const task of tasks || []) {
      let taskPath = (task.path || '').replaceAll('\\', '/');
      // Convert absolute paths to relative paths
      if (path.isAbsolute(taskPath)) {
        taskPath = path.relative(skadDir, taskPath).replaceAll('\\', '/');
      }
      // Remove _skad/ prefix if present to get relative path within skad folder
      if (taskPath.startsWith(skadPrefix)) {
        taskPath = taskPath.slice(skadPrefix.length);
      }

      const taskExt = path.extname(taskPath) || '.md';
      artifacts.push({
        type: 'task',
        name: task.name,
        displayName: task.displayName || task.name,
        description: task.description || `Execute ${task.displayName || task.name}`,
        module: task.module,
        // Use forward slashes for cross-platform consistency (not path.join which uses backslashes on Windows)
        relativePath: `${task.module}/tasks/${task.name}${taskExt}`,
        path: taskPath,
      });
    }

    // Collect tool artifacts
    for (const tool of tools || []) {
      let toolPath = (tool.path || '').replaceAll('\\', '/');
      // Convert absolute paths to relative paths
      if (path.isAbsolute(toolPath)) {
        toolPath = path.relative(skadDir, toolPath).replaceAll('\\', '/');
      }
      // Remove _skad/ prefix if present to get relative path within skad folder
      if (toolPath.startsWith(skadPrefix)) {
        toolPath = toolPath.slice(skadPrefix.length);
      }

      const toolExt = path.extname(toolPath) || '.md';
      artifacts.push({
        type: 'tool',
        name: tool.name,
        displayName: tool.displayName || tool.name,
        description: tool.description || `Execute ${tool.displayName || tool.name}`,
        module: tool.module,
        // Use forward slashes for cross-platform consistency (not path.join which uses backslashes on Windows)
        relativePath: `${tool.module}/tools/${tool.name}${toolExt}`,
        path: toolPath,
      });
    }

    return {
      artifacts,
      counts: {
        tasks: (tasks || []).length,
        tools: (tools || []).length,
      },
    };
  }

  /**
   * Generate task and tool commands from manifest CSVs
   * @param {string} projectDir - Project directory
   * @param {string} skadDir - SKAD installation directory
   * @param {string} baseCommandsDir - Optional base commands directory (defaults to .claude/commands/skad)
   */
  async generateTaskToolCommands(projectDir, skadDir, baseCommandsDir = null) {
    const tasks = await this.loadTaskManifest(skadDir);
    const tools = await this.loadToolManifest(skadDir);

    // Base commands directory - use provided or default to Claude Code structure
    const commandsDir = baseCommandsDir || path.join(projectDir, '.claude', 'commands', 'skad');

    let generatedCount = 0;

    // Generate command files for tasks
    for (const task of tasks || []) {
      const moduleTasksDir = path.join(commandsDir, task.module, 'tasks');
      await fs.ensureDir(moduleTasksDir);

      const commandContent = this.generateCommandContent(task, 'task');
      const commandPath = path.join(moduleTasksDir, `${task.name}.md`);

      await fs.writeFile(commandPath, commandContent);
      generatedCount++;
    }

    // Generate command files for tools
    for (const tool of tools || []) {
      const moduleToolsDir = path.join(commandsDir, tool.module, 'tools');
      await fs.ensureDir(moduleToolsDir);

      const commandContent = this.generateCommandContent(tool, 'tool');
      const commandPath = path.join(moduleToolsDir, `${tool.name}.md`);

      await fs.writeFile(commandPath, commandContent);
      generatedCount++;
    }

    return {
      generated: generatedCount,
      tasks: (tasks || []).length,
      tools: (tools || []).length,
    };
  }

  /**
   * Generate command content for a task or tool
   */
  generateCommandContent(item, type) {
    const description = item.description || `Execute ${item.displayName || item.name}`;

    // Convert path to use {project-root} placeholder
    // Handle undefined/missing path by constructing from module and name
    let itemPath = item.path;
    if (!itemPath || typeof itemPath !== 'string') {
      // Fallback: construct path from module and name if path is missing
      const typePlural = type === 'task' ? 'tasks' : 'tools';
      itemPath = `{project-root}/${this.skadFolderName}/${item.module}/${typePlural}/${item.name}.md`;
    } else {
      // Normalize path separators to forward slashes
      itemPath = itemPath.replaceAll('\\', '/');

      // Extract relative path from absolute paths (Windows or Unix)
      // Look for _skad/ or skad/ in the path and extract everything after it
      // Match patterns like: /_skad/core/tasks/... or /skad/core/tasks/...
      // Use [/\\] to handle both Unix forward slashes and Windows backslashes,
      // and also paths without a leading separator (e.g., C:/_skad/...)
      const skadMatch = itemPath.match(/[/\\]_skad[/\\](.+)$/) || itemPath.match(/[/\\]skad[/\\](.+)$/);
      if (skadMatch) {
        // Found /_skad/ or /skad/ - use relative path after it
        itemPath = `{project-root}/${this.skadFolderName}/${skadMatch[1]}`;
      } else if (itemPath.startsWith(`${SKAD_FOLDER_NAME}/`)) {
        // Relative path starting with _skad/
        itemPath = `{project-root}/${this.skadFolderName}/${itemPath.slice(SKAD_FOLDER_NAME.length + 1)}`;
      } else if (itemPath.startsWith('skad/')) {
        // Relative path starting with skad/
        itemPath = `{project-root}/${this.skadFolderName}/${itemPath.slice(5)}`;
      } else if (!itemPath.startsWith('{project-root}')) {
        // For other relative paths, prefix with project root and skad folder
        itemPath = `{project-root}/${this.skadFolderName}/${itemPath}`;
      }
    }

    return `---
description: '${description.replaceAll("'", "''")}'
disable-model-invocation: true
---

# ${item.displayName || item.name}

Read the entire ${type} file at: ${itemPath}

Follow all instructions in the ${type} file exactly as written.
`;
  }

  /**
   * Load task manifest CSV
   */
  async loadTaskManifest(skadDir) {
    const manifestPath = path.join(skadDir, '_config', 'task-manifest.csv');

    if (!(await fs.pathExists(manifestPath))) {
      return null;
    }

    const csvContent = await fs.readFile(manifestPath, 'utf8');
    return csv.parse(csvContent, {
      columns: true,
      skip_empty_lines: true,
    });
  }

  /**
   * Load tool manifest CSV
   */
  async loadToolManifest(skadDir) {
    const manifestPath = path.join(skadDir, '_config', 'tool-manifest.csv');

    if (!(await fs.pathExists(manifestPath))) {
      return null;
    }

    const csvContent = await fs.readFile(manifestPath, 'utf8');
    return csv.parse(csvContent, {
      columns: true,
      skip_empty_lines: true,
    });
  }

  /**
   * Generate task and tool commands using underscore format (Windows-compatible)
   * Creates flat files like: skad_skm_help.md
   *
   * @param {string} projectDir - Project directory
   * @param {string} skadDir - SKAD installation directory
   * @param {string} baseCommandsDir - Base commands directory for the IDE
   * @returns {Object} Generation results
   */
  async generateColonTaskToolCommands(projectDir, skadDir, baseCommandsDir) {
    const tasks = await this.loadTaskManifest(skadDir);
    const tools = await this.loadToolManifest(skadDir);

    let generatedCount = 0;

    // Generate command files for tasks
    for (const task of tasks || []) {
      const commandContent = this.generateCommandContent(task, 'task');
      // Use underscore format: skad_skm_name.md
      const flatName = toColonName(task.module, 'tasks', task.name);
      const commandPath = path.join(baseCommandsDir, flatName);
      await fs.ensureDir(path.dirname(commandPath));
      await fs.writeFile(commandPath, commandContent);
      generatedCount++;
    }

    // Generate command files for tools
    for (const tool of tools || []) {
      const commandContent = this.generateCommandContent(tool, 'tool');
      // Use underscore format: skad_skm_name.md
      const flatName = toColonName(tool.module, 'tools', tool.name);
      const commandPath = path.join(baseCommandsDir, flatName);
      await fs.ensureDir(path.dirname(commandPath));
      await fs.writeFile(commandPath, commandContent);
      generatedCount++;
    }

    return {
      generated: generatedCount,
      tasks: (tasks || []).length,
      tools: (tools || []).length,
    };
  }

  /**
   * Generate task and tool commands using underscore format (Windows-compatible)
   * Creates flat files like: skad_skm_help.md
   *
   * @param {string} projectDir - Project directory
   * @param {string} skadDir - SKAD installation directory
   * @param {string} baseCommandsDir - Base commands directory for the IDE
   * @returns {Object} Generation results
   */
  async generateDashTaskToolCommands(projectDir, skadDir, baseCommandsDir) {
    const tasks = await this.loadTaskManifest(skadDir);
    const tools = await this.loadToolManifest(skadDir);

    let generatedCount = 0;

    // Generate command files for tasks
    for (const task of tasks || []) {
      const commandContent = this.generateCommandContent(task, 'task');
      // Use dash format: skad-skm-name.md
      const flatName = toDashPath(`${task.module}/tasks/${task.name}.md`);
      const commandPath = path.join(baseCommandsDir, flatName);
      await fs.ensureDir(path.dirname(commandPath));
      await fs.writeFile(commandPath, commandContent);
      generatedCount++;
    }

    // Generate command files for tools
    for (const tool of tools || []) {
      const commandContent = this.generateCommandContent(tool, 'tool');
      // Use dash format: skad-skm-name.md
      const flatName = toDashPath(`${tool.module}/tools/${tool.name}.md`);
      const commandPath = path.join(baseCommandsDir, flatName);
      await fs.ensureDir(path.dirname(commandPath));
      await fs.writeFile(commandPath, commandContent);
      generatedCount++;
    }

    return {
      generated: generatedCount,
      tasks: (tasks || []).length,
      tools: (tools || []).length,
    };
  }

  /**
   * Write task/tool artifacts using underscore format (Windows-compatible)
   * Creates flat files like: skad_skm_help.md
   *
   * @param {string} baseCommandsDir - Base commands directory for the IDE
   * @param {Array} artifacts - Task/tool artifacts with relativePath
   * @returns {number} Count of commands written
   */
  async writeColonArtifacts(baseCommandsDir, artifacts) {
    let writtenCount = 0;

    for (const artifact of artifacts) {
      if (artifact.type === 'task' || artifact.type === 'tool') {
        const commandContent = this.generateCommandContent(artifact, artifact.type);
        // Use underscore format: skad_module_name.md
        const flatName = toColonPath(artifact.relativePath);
        const commandPath = path.join(baseCommandsDir, flatName);
        await fs.ensureDir(path.dirname(commandPath));
        await fs.writeFile(commandPath, commandContent);
        writtenCount++;
      }
    }

    return writtenCount;
  }

  /**
   * Write task/tool artifacts using dash format (NEW STANDARD)
   * Creates flat files like: skad-skm-help.md
   *
   * Note: Tasks/tools do NOT have skad-agent- prefix - only agents do.
   *
   * @param {string} baseCommandsDir - Base commands directory for the IDE
   * @param {Array} artifacts - Task/tool artifacts with relativePath
   * @returns {number} Count of commands written
   */
  async writeDashArtifacts(baseCommandsDir, artifacts) {
    let writtenCount = 0;

    for (const artifact of artifacts) {
      if (artifact.type === 'task' || artifact.type === 'tool') {
        const commandContent = this.generateCommandContent(artifact, artifact.type);
        // Use dash format: skad-module-name.md
        const flatName = toDashPath(artifact.relativePath);
        const commandPath = path.join(baseCommandsDir, flatName);
        await fs.ensureDir(path.dirname(commandPath));
        await fs.writeFile(commandPath, commandContent);
        writtenCount++;
      }
    }

    return writtenCount;
  }
}

module.exports = { TaskToolCommandGenerator };
