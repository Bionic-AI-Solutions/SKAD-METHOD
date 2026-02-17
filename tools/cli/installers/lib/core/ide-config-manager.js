const path = require('node:path');
const fs = require('fs-extra');
const yaml = require('yaml');

/**
 * Manages IDE configuration persistence
 * Saves and loads IDE-specific configurations to/from skad/_config/ides/
 */
class IdeConfigManager {
  constructor() {}

  /**
   * Get path to IDE config directory
   * @param {string} skadDir - SKAD installation directory
   * @returns {string} Path to IDE config directory
   */
  getIdeConfigDir(skadDir) {
    return path.join(skadDir, '_config', 'ides');
  }

  /**
   * Get path to specific IDE config file
   * @param {string} skadDir - SKAD installation directory
   * @param {string} ideName - IDE name (e.g., 'claude-code')
   * @returns {string} Path to IDE config file
   */
  getIdeConfigPath(skadDir, ideName) {
    return path.join(this.getIdeConfigDir(skadDir), `${ideName}.yaml`);
  }

  /**
   * Save IDE configuration
   * @param {string} skadDir - SKAD installation directory
   * @param {string} ideName - IDE name
   * @param {Object} configuration - IDE-specific configuration object
   */
  async saveIdeConfig(skadDir, ideName, configuration) {
    const configDir = this.getIdeConfigDir(skadDir);
    await fs.ensureDir(configDir);

    const configPath = this.getIdeConfigPath(skadDir, ideName);
    const now = new Date().toISOString();

    // Check if config already exists to preserve configured_date
    let configuredDate = now;
    if (await fs.pathExists(configPath)) {
      try {
        const existing = await this.loadIdeConfig(skadDir, ideName);
        if (existing && existing.configured_date) {
          configuredDate = existing.configured_date;
        }
      } catch {
        // Ignore errors reading existing config
      }
    }

    const configData = {
      ide: ideName,
      configured_date: configuredDate,
      last_updated: now,
      configuration: configuration || {},
    };

    // Clean the config to remove any non-serializable values (like functions)
    const cleanConfig = structuredClone(configData);

    const yamlContent = yaml.stringify(cleanConfig, {
      indent: 2,
      lineWidth: 0,
      sortKeys: false,
    });

    // Ensure POSIX-compliant final newline
    const content = yamlContent.endsWith('\n') ? yamlContent : yamlContent + '\n';
    await fs.writeFile(configPath, content, 'utf8');
  }

  /**
   * Load IDE configuration
   * @param {string} skadDir - SKAD installation directory
   * @param {string} ideName - IDE name
   * @returns {Object|null} IDE configuration or null if not found
   */
  async loadIdeConfig(skadDir, ideName) {
    const configPath = this.getIdeConfigPath(skadDir, ideName);

    if (!(await fs.pathExists(configPath))) {
      return null;
    }

    try {
      const content = await fs.readFile(configPath, 'utf8');
      const config = yaml.parse(content);
      return config;
    } catch (error) {
      console.warn(`Warning: Failed to load IDE config for ${ideName}:`, error.message);
      return null;
    }
  }

  /**
   * Load all IDE configurations
   * @param {string} skadDir - SKAD installation directory
   * @returns {Object} Map of IDE name to configuration
   */
  async loadAllIdeConfigs(skadDir) {
    const configDir = this.getIdeConfigDir(skadDir);
    const configs = {};

    if (!(await fs.pathExists(configDir))) {
      return configs;
    }

    try {
      const files = await fs.readdir(configDir);
      for (const file of files) {
        if (file.endsWith('.yaml')) {
          const ideName = file.replace('.yaml', '');
          const config = await this.loadIdeConfig(skadDir, ideName);
          if (config) {
            configs[ideName] = config.configuration;
          }
        }
      }
    } catch (error) {
      console.warn('Warning: Failed to load IDE configs:', error.message);
    }

    return configs;
  }

  /**
   * Check if IDE has saved configuration
   * @param {string} skadDir - SKAD installation directory
   * @param {string} ideName - IDE name
   * @returns {boolean} True if configuration exists
   */
  async hasIdeConfig(skadDir, ideName) {
    const configPath = this.getIdeConfigPath(skadDir, ideName);
    return await fs.pathExists(configPath);
  }

  /**
   * Delete IDE configuration
   * @param {string} skadDir - SKAD installation directory
   * @param {string} ideName - IDE name
   */
  async deleteIdeConfig(skadDir, ideName) {
    const configPath = this.getIdeConfigPath(skadDir, ideName);
    if (await fs.pathExists(configPath)) {
      await fs.remove(configPath);
    }
  }
}

module.exports = { IdeConfigManager };
