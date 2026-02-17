const path = require('node:path');
const prompts = require('../lib/prompts');
const { Installer } = require('../installers/lib/core/installer');
const { Manifest } = require('../installers/lib/core/manifest');
const { UI } = require('../lib/ui');

const installer = new Installer();
const manifest = new Manifest();
const ui = new UI();

module.exports = {
  command: 'status',
  description: 'Display SKAD installation status and module versions',
  options: [],
  action: async (options) => {
    try {
      // Find the skad directory
      const projectDir = process.cwd();
      const { skadDir } = await installer.findSkadDir(projectDir);

      // Check if skad directory exists
      const fs = require('fs-extra');
      if (!(await fs.pathExists(skadDir))) {
        await prompts.log.warn('No SKAD installation found in the current directory.');
        await prompts.log.message(`Expected location: ${skadDir}`);
        await prompts.log.message('Run "skad install" to set up a new installation.');
        process.exit(0);
        return;
      }

      // Read manifest
      const manifestData = await manifest._readRaw(skadDir);

      if (!manifestData) {
        await prompts.log.warn('No SKAD installation manifest found.');
        await prompts.log.message('Run "skad install" to set up a new installation.');
        process.exit(0);
        return;
      }

      // Get installation info
      const installation = manifestData.installation || {};
      const modules = manifestData.modules || [];

      // Check for available updates (only for external modules)
      const availableUpdates = await manifest.checkForUpdates(skadDir);

      // Display status
      await ui.displayStatus({
        installation,
        modules,
        availableUpdates,
        skadDir,
      });

      process.exit(0);
    } catch (error) {
      await prompts.log.error(`Status check failed: ${error.message}`);
      if (process.env.SKAD_DEBUG) {
        await prompts.log.message(error.stack);
      }
      process.exit(1);
    }
  },
};
