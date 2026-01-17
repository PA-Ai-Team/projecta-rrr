#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

// Colors
const cyan = '\x1b[36m';
const green = '\x1b[32m';
const yellow = '\x1b[33m';
const orange = '\x1b[91m'; // bright red (more compatible than 256-color)
const dim = '\x1b[2m';
const reset = '\x1b[0m';

// Get version from package.json
const pkg = require('../package.json');

/**
 * Render banner with TTY-aware formatting
 * - Boxed ASCII banner for TTY with sufficient width
 * - Plain text fallback for non-TTY or narrow terminals
 */
function renderBanner({ name, version, org, tagline }) {
  const isTTY = process.stdout.isTTY;
  const columns = process.stdout.columns || 80;
  const useBox = isTTY && columns >= 50;

  if (useBox) {
    // Boxed banner with ASCII borders (no Unicode box-drawing)
    const boxWidth = Math.min(46, columns - 4);
    const innerWidth = boxWidth - 4; // Account for "| " and " |"

    const pad = (str, len) => str + ' '.repeat(Math.max(0, len - str.length));
    const line1 = `${name} v${version}`;
    const line2 = org;
    const line3 = tagline;

    const border = '+' + '-'.repeat(boxWidth - 2) + '+';

    return `
${yellow}${border}
|  ${reset}${line1}${yellow}${' '.repeat(Math.max(0, innerWidth - line1.length))}  |
|  ${reset}${line2}${yellow}${' '.repeat(Math.max(0, innerWidth - line2.length))}  |
|  ${reset}${dim}${line3}${reset}${yellow}${' '.repeat(Math.max(0, innerWidth - line3.length))}  |
${border}${reset}
`;
  } else {
    // Plain banner for non-TTY or narrow terminals
    return `
${name} v${version} - ${org}
${tagline}
`;
  }
}

const banner = renderBanner({
  name: 'RRR',
  version: pkg.version,
  org: 'Projecta.ai',
  tagline: 'Spec-driven development for Claude Code'
});

// Parse args
const args = process.argv.slice(2);
const hasGlobal = args.includes('--global') || args.includes('-g');
const hasLocal = args.includes('--local') || args.includes('-l');

// Parse --config-dir argument
function parseConfigDirArg() {
  const configDirIndex = args.findIndex(arg => arg === '--config-dir' || arg === '-c');
  if (configDirIndex !== -1) {
    const nextArg = args[configDirIndex + 1];
    // Error if --config-dir is provided without a value or next arg is another flag
    if (!nextArg || nextArg.startsWith('-')) {
      console.error(`  ${yellow}--config-dir requires a path argument${reset}`);
      process.exit(1);
    }
    return nextArg;
  }
  // Also handle --config-dir=value format
  const configDirArg = args.find(arg => arg.startsWith('--config-dir=') || arg.startsWith('-c='));
  if (configDirArg) {
    return configDirArg.split('=')[1];
  }
  return null;
}
const explicitConfigDir = parseConfigDirArg();
const hasHelp = args.includes('--help') || args.includes('-h');
const forceStatusline = args.includes('--force-statusline');
const forceNotify = args.includes('--force-notify');
const noNotify = args.includes('--no-notify');

console.log(banner);

// Show help if requested
if (hasHelp) {
  console.log(`  ${yellow}Usage:${reset} npx projecta-rrr [options]

  ${yellow}Options:${reset}
    ${cyan}-g, --global${reset}              Install globally (to Claude config directory)
    ${cyan}-l, --local${reset}               Install locally (to ./.claude in current directory)
    ${cyan}-c, --config-dir <path>${reset}   Specify custom Claude config directory
    ${cyan}-h, --help${reset}                Show this help message
    ${cyan}--force-statusline${reset}        Replace existing statusline config
    ${cyan}--force-notify${reset}            Replace existing notification hook
    ${cyan}--no-notify${reset}               Skip notification hook installation

  ${yellow}Examples:${reset}
    ${dim}# Install to default ~/.claude directory${reset}
    npx projecta-rrr --global

    ${dim}# Install to custom config directory (for multiple Claude accounts)${reset}
    npx projecta-rrr --global --config-dir ~/.claude-bc

    ${dim}# Using environment variable${reset}
    CLAUDE_CONFIG_DIR=~/.claude-bc npx projecta-rrr --global

    ${dim}# Install to current project only${reset}
    npx projecta-rrr --local

  ${yellow}Notes:${reset}
    The --config-dir option is useful when you have multiple Claude Code
    configurations (e.g., for different subscriptions). It takes priority
    over the CLAUDE_CONFIG_DIR environment variable.
`);
  process.exit(0);
}

/**
 * Expand ~ to home directory (shell doesn't expand in env vars passed to node)
 */
function expandTilde(filePath) {
  if (filePath && filePath.startsWith('~/')) {
    return path.join(os.homedir(), filePath.slice(2));
  }
  return filePath;
}

/**
 * Read and parse settings.json, returning empty object if doesn't exist
 */
function readSettings(settingsPath) {
  if (fs.existsSync(settingsPath)) {
    try {
      return JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    } catch (e) {
      return {};
    }
  }
  return {};
}

/**
 * Write settings.json with proper formatting
 */
function writeSettings(settingsPath, settings) {
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
}

/**
 * Count skill directories in a given directory (looks for SKILL.md files)
 */
function countSkillsInDir(dir) {
  if (!fs.existsSync(dir)) return 0;
  let count = 0;
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.isDirectory()) {
        const skillFile = path.join(dir, entry.name, 'SKILL.md');
        if (fs.existsSync(skillFile)) {
          count++;
        }
      }
    }
  } catch (e) {
    // Ignore errors
  }
  return count;
}

/**
 * Recursively copy directory, replacing paths in .md files
 */
function copyWithPathReplacement(srcDir, destDir, pathPrefix) {
  fs.mkdirSync(destDir, { recursive: true });

  const entries = fs.readdirSync(srcDir, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(srcDir, entry.name);
    const destPath = path.join(destDir, entry.name);

    if (entry.isDirectory()) {
      copyWithPathReplacement(srcPath, destPath, pathPrefix);
    } else if (entry.name.endsWith('.md')) {
      // Replace ~/.claude/ with the appropriate prefix in markdown files
      let content = fs.readFileSync(srcPath, 'utf8');
      content = content.replace(/~\/\.claude\//g, pathPrefix);
      fs.writeFileSync(destPath, content);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

/**
 * Install scripts to target project (for Pushpa Mode and MCP setup)
 */
function installScripts(targetDir) {
  const src = path.join(__dirname, '..');
  const scriptsDir = path.join(targetDir, 'scripts');
  const srcScriptsDir = path.join(src, 'scripts');

  // Check if source scripts directory exists
  if (!fs.existsSync(srcScriptsDir)) {
    return { installed: [], skipped: [] };
  }

  // Create scripts directory in target if needed
  fs.mkdirSync(scriptsDir, { recursive: true });

  const installed = [];
  const skipped = [];
  const scripts = ['pushpa-mode.sh', 'mcp-setup.sh', 'visual-proof.sh'];

  for (const script of scripts) {
    const srcFile = path.join(srcScriptsDir, script);
    const destFile = path.join(scriptsDir, script);

    if (!fs.existsSync(srcFile)) {
      continue; // Source script doesn't exist, skip
    }

    if (fs.existsSync(destFile)) {
      skipped.push(script);
      console.log(`  ${yellow}⚠${reset} Skipped scripts/${script} (already exists)`);
    } else {
      fs.copyFileSync(srcFile, destFile);
      // Set executable bit on Unix systems
      try {
        fs.chmodSync(destFile, 0o755);
      } catch (e) {
        // Ignore chmod errors (Windows)
      }
      installed.push(script);
      console.log(`  ${green}✓${reset} Installed scripts/${script}`);
    }
  }

  return { installed, skipped };
}

/**
 * Add npm scripts to target package.json
 */
function addNpmScripts(targetDir, installedScripts) {
  const pkgPath = path.join(targetDir, 'package.json');

  if (!fs.existsSync(pkgPath)) {
    return { added: [], skipped: [] };
  }

  let pkgJson;
  try {
    pkgJson = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  } catch (e) {
    console.log(`  ${yellow}⚠${reset} Could not parse package.json, skipping npm scripts`);
    return { added: [], skipped: [] };
  }

  if (!pkgJson.scripts) {
    pkgJson.scripts = {};
  }

  const added = [];
  const skipped = [];

  // Add pushpa script if pushpa-mode.sh was installed
  if (installedScripts.includes('pushpa-mode.sh') || fs.existsSync(path.join(targetDir, 'scripts', 'pushpa-mode.sh'))) {
    if (pkgJson.scripts.pushpa) {
      skipped.push('pushpa');
      console.log(`  ${yellow}⚠${reset} Skipped npm script "pushpa" (already exists)`);
    } else {
      pkgJson.scripts.pushpa = 'bash scripts/pushpa-mode.sh';
      added.push('pushpa');
      console.log(`  ${green}✓${reset} Added npm script "pushpa"`);
    }
  }

  // Add mcp:setup script if mcp-setup.sh was installed
  if (installedScripts.includes('mcp-setup.sh') || fs.existsSync(path.join(targetDir, 'scripts', 'mcp-setup.sh'))) {
    if (pkgJson.scripts['mcp:setup']) {
      skipped.push('mcp:setup');
      console.log(`  ${yellow}⚠${reset} Skipped npm script "mcp:setup" (already exists)`);
    } else {
      pkgJson.scripts['mcp:setup'] = 'bash scripts/mcp-setup.sh';
      added.push('mcp:setup');
      console.log(`  ${green}✓${reset} Added npm script "mcp:setup"`);
    }
  }

  // Add visual:proof script if visual-proof.sh was installed
  if (installedScripts.includes('visual-proof.sh') || fs.existsSync(path.join(targetDir, 'scripts', 'visual-proof.sh'))) {
    if (pkgJson.scripts['visual:proof']) {
      skipped.push('visual:proof');
      console.log(`  ${yellow}⚠${reset} Skipped npm script "visual:proof" (already exists)`);
    } else {
      pkgJson.scripts['visual:proof'] = 'bash scripts/visual-proof.sh';
      added.push('visual:proof');
      console.log(`  ${green}✓${reset} Added npm script "visual:proof"`);
    }
  }

  // Write back if we added anything
  if (added.length > 0) {
    fs.writeFileSync(pkgPath, JSON.stringify(pkgJson, null, 2) + '\n');
  }

  return { added, skipped };
}

/**
 * Install to the specified directory
 */
function install(isGlobal) {
  const src = path.join(__dirname, '..');
  // Priority: explicit --config-dir arg > CLAUDE_CONFIG_DIR env var > default ~/.claude
  const configDir = expandTilde(explicitConfigDir) || expandTilde(process.env.CLAUDE_CONFIG_DIR);
  const defaultGlobalDir = configDir || path.join(os.homedir(), '.claude');
  const claudeDir = isGlobal
    ? defaultGlobalDir
    : path.join(process.cwd(), '.claude');

  const locationLabel = isGlobal
    ? claudeDir.replace(os.homedir(), '~')
    : claudeDir.replace(process.cwd(), '.');

  // Path prefix for file references
  // Use actual path when CLAUDE_CONFIG_DIR is set, otherwise use ~ shorthand
  const pathPrefix = isGlobal
    ? (configDir ? `${claudeDir}/` : '~/.claude/')
    : './.claude/';

  console.log(`  Installing to ${cyan}${locationLabel}${reset}\n`);

  // Create commands directory
  const commandsDir = path.join(claudeDir, 'commands');
  fs.mkdirSync(commandsDir, { recursive: true });

  // Copy commands/rrr with path replacement
  const rrrSrc = path.join(src, 'commands', 'rrr');
  const rrrDest = path.join(commandsDir, 'rrr');
  copyWithPathReplacement(rrrSrc, rrrDest, pathPrefix);
  console.log(`  ${green}✓${reset} Installed commands/rrr`);

  // Copy rrr skill with path replacement
  const skillSrc = path.join(src, 'rrr');
  const skillDest = path.join(claudeDir, 'rrr');
  copyWithPathReplacement(skillSrc, skillDest, pathPrefix);
  console.log(`  ${green}✓${reset} Installed rrr`);

  // Copy agents to ~/.claude/agents (subagents must be at root level)
  const agentsSrc = path.join(src, 'agents');
  if (fs.existsSync(agentsSrc)) {
    const agentsDest = path.join(claudeDir, 'agents');
    copyWithPathReplacement(agentsSrc, agentsDest, pathPrefix);
    console.log(`  ${green}✓${reset} Installed agents`);
  }

  // Copy skills to ~/.claude/skills (skills system)
  const skillsSrc = path.join(src, 'rrr', 'skills');
  if (fs.existsSync(skillsSrc)) {
    const skillsDest = path.join(claudeDir, 'skills');
    copyWithPathReplacement(skillsSrc, skillsDest, pathPrefix);
    // Count skills by category
    const projectaCount = countSkillsInDir(path.join(skillsSrc, 'projecta'));
    const anthropicCount = countSkillsInDir(path.join(skillsSrc, 'upstream', 'anthropic'));
    console.log(`  ${green}✓${reset} Installed skills/projecta (${projectaCount} skills)`);
    if (anthropicCount > 0) {
      console.log(`  ${green}✓${reset} Installed skills/upstream/anthropic (${anthropicCount} skills)`);
    }
  }

  // Copy CHANGELOG.md
  const changelogSrc = path.join(src, 'CHANGELOG.md');
  const changelogDest = path.join(claudeDir, 'rrr', 'CHANGELOG.md');
  if (fs.existsSync(changelogSrc)) {
    fs.copyFileSync(changelogSrc, changelogDest);
    console.log(`  ${green}✓${reset} Installed CHANGELOG.md`);
  }

  // Write VERSION file for whats-new command
  const versionDest = path.join(claudeDir, 'rrr', 'VERSION');
  fs.writeFileSync(versionDest, pkg.version);
  console.log(`  ${green}✓${reset} Wrote VERSION (${pkg.version})`);

  // Copy hooks
  const hooksSrc = path.join(src, 'hooks');
  if (fs.existsSync(hooksSrc)) {
    const hooksDest = path.join(claudeDir, 'hooks');
    fs.mkdirSync(hooksDest, { recursive: true });
    const hookEntries = fs.readdirSync(hooksSrc);
    for (const entry of hookEntries) {
      const srcFile = path.join(hooksSrc, entry);
      const destFile = path.join(hooksDest, entry);
      fs.copyFileSync(srcFile, destFile);
      // Make shell scripts executable
      if (entry.endsWith('.sh')) {
        fs.chmodSync(destFile, 0o755);
      }
    }
    console.log(`  ${green}✓${reset} Installed hooks`);
  }

  // Configure statusline and hooks in settings.json
  const settingsPath = path.join(claudeDir, 'settings.json');
  const settings = readSettings(settingsPath);
  const statuslineCommand = isGlobal
    ? '$HOME/.claude/hooks/statusline.sh'
    : '.claude/hooks/statusline.sh';
  const updateCheckCommand = isGlobal
    ? '$HOME/.claude/hooks/rrr-check-update.sh'
    : '.claude/hooks/rrr-check-update.sh';
  const notifyCommand = isGlobal
    ? '$HOME/.claude/hooks/rrr-notify.sh'
    : '.claude/hooks/rrr-notify.sh';

  // Configure SessionStart hook for update checking
  if (!settings.hooks) {
    settings.hooks = {};
  }
  if (!settings.hooks.SessionStart) {
    settings.hooks.SessionStart = [];
  }

  // Check if RRR update hook already exists
  const hasRrrUpdateHook = settings.hooks.SessionStart.some(entry =>
    entry.hooks && entry.hooks.some(h => h.command && h.command.includes('rrr-check-update'))
  );

  if (!hasRrrUpdateHook) {
    settings.hooks.SessionStart.push({
      hooks: [
        {
          type: 'command',
          command: updateCheckCommand
        }
      ]
    });
    console.log(`  ${green}✓${reset} Configured update check hook`);
  }

  // Install Pushpa Mode and MCP setup scripts to the project directory
  // For local install, use current directory; for global, also install to cwd if it has package.json
  const projectDir = process.cwd();
  const projectPkgPath = path.join(projectDir, 'package.json');
  const hasProjectPkg = fs.existsSync(projectPkgPath);

  if (hasProjectPkg) {
    console.log(`\n  ${cyan}Installing project scripts to ${projectDir.replace(os.homedir(), '~')}${reset}\n`);
    const { installed, skipped } = installScripts(projectDir);

    // Add npm scripts if we have package.json
    const allInstalledScripts = [...installed];
    // Include skipped scripts since they already exist
    skipped.forEach(s => allInstalledScripts.push(s));
    addNpmScripts(projectDir, allInstalledScripts);
  }

  return { settingsPath, settings, statuslineCommand, notifyCommand };
}

/**
 * Apply statusline and notification config, then print completion message
 */
function finishInstall(settingsPath, settings, statuslineCommand, notifyCommand, shouldInstallStatusline, shouldInstallNotify) {
  if (shouldInstallStatusline) {
    settings.statusLine = {
      type: 'command',
      command: statuslineCommand
    };
    console.log(`  ${green}✓${reset} Configured statusline`);
  }

  if (shouldInstallNotify) {
    if (!settings.hooks.Stop) {
      settings.hooks.Stop = [];
    }
    // Remove any existing RRR notify hook first
    settings.hooks.Stop = settings.hooks.Stop.filter(entry =>
      !(entry.hooks && entry.hooks.some(h => h.command && h.command.includes('rrr-notify')))
    );
    settings.hooks.Stop.push({
      hooks: [
        {
          type: 'command',
          command: notifyCommand
        }
      ]
    });
    console.log(`  ${green}✓${reset} Configured completion notifications`);
  }

  // Always write settings (hooks were already configured in install())
  writeSettings(settingsPath, settings);

  console.log(`
  ${green}Done!${reset}

  ${yellow}If you installed from inside Claude Code:${reset}
  Type ${cyan}exit${reset} and restart ${cyan}claude${reset} so it reloads commands.

  ${yellow}Pick your start command:${reset}

  ${cyan}New/empty folder (greenfield)${reset}
    /rrr:new-project
    (bootstraps Next.js/TS baseline if folder is empty)

  ${cyan}Existing repo (brownfield)${reset}
    /rrr:new-project
    (brownfield-safe; won't overwrite or restructure your repo)

  ${cyan}RRR already initialized${reset}
    /rrr:progress
    (if .planning/STATE.md exists)

  Run ${cyan}/rrr:help${reset} anytime to see all commands.
`);
}

/**
 * Handle statusline configuration with optional prompt
 */
function handleStatusline(settings, isInteractive, callback) {
  const hasExisting = settings.statusLine != null;

  // No existing statusline - just install it
  if (!hasExisting) {
    callback(true);
    return;
  }

  // Has existing and --force-statusline flag
  if (forceStatusline) {
    callback(true);
    return;
  }

  // Has existing, non-interactive mode - skip
  if (!isInteractive) {
    console.log(`  ${yellow}⚠${reset} Skipping statusline (already configured)`);
    console.log(`    Use ${cyan}--force-statusline${reset} to replace\n`);
    callback(false);
    return;
  }

  // Has existing, interactive mode - prompt user
  const existingCmd = settings.statusLine.command || settings.statusLine.url || '(custom)';

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  console.log(`
  ${yellow}⚠${reset} Existing statusline detected

  Your current statusline:
    ${dim}command: ${existingCmd}${reset}

  RRR includes a statusline showing:
    • Model name
    • Current task (from todo list)
    • Context window usage (color-coded)

  ${cyan}1${reset}) Keep existing
  ${cyan}2${reset}) Replace with RRR statusline
`);

  rl.question(`  Choice ${dim}[1]${reset}: `, (answer) => {
    rl.close();
    const choice = answer.trim() || '1';
    callback(choice === '2');
  });
}

/**
 * Handle notification hook configuration with optional prompt
 */
function handleNotifications(settings, isInteractive, callback) {
  // Check if --no-notify flag was passed
  if (noNotify) {
    callback(false);
    return;
  }

  // Check if RRR notify hook already exists
  const hasExisting = settings.hooks?.Stop?.some(entry =>
    entry.hooks && entry.hooks.some(h => h.command && h.command.includes('rrr-notify'))
  );

  // No existing - just install it
  if (!hasExisting) {
    callback(true);
    return;
  }

  // Has existing and --force-notify flag
  if (forceNotify) {
    callback(true);
    return;
  }

  // Has existing, non-interactive mode - skip
  if (!isInteractive) {
    console.log(`  ${yellow}⚠${reset} Skipping notifications (already configured)`);
    console.log(`    Use ${cyan}--force-notify${reset} to replace\n`);
    callback(false);
    return;
  }

  // Has existing, interactive mode - prompt user
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  console.log(`
  ${yellow}⚠${reset} Existing notification hook detected

  RRR includes completion notifications that alert you when:
    • A phase completes planning or execution
    • Claude stops and needs your input
    • Works on Mac, Linux, and Windows

  ${cyan}1${reset}) Keep existing
  ${cyan}2${reset}) Replace with RRR notifications
`);

  rl.question(`  Choice ${dim}[1]${reset}: `, (answer) => {
    rl.close();
    const choice = answer.trim() || '1';
    callback(choice === '2');
  });
}

/**
 * Prompt for install location
 */
function promptLocation() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const configDir = expandTilde(explicitConfigDir) || expandTilde(process.env.CLAUDE_CONFIG_DIR);
  const globalPath = configDir || path.join(os.homedir(), '.claude');
  const globalLabel = globalPath.replace(os.homedir(), '~');

  console.log(`  ${yellow}Where would you like to install?${reset}

  ${cyan}1${reset}) Global ${dim}(${globalLabel})${reset} - available in all projects
  ${cyan}2${reset}) Local  ${dim}(./.claude)${reset} - this project only
`);

  rl.question(`  Choice ${dim}[1]${reset}: `, (answer) => {
    rl.close();
    const choice = answer.trim() || '1';
    const isGlobal = choice !== '2';
    const { settingsPath, settings, statuslineCommand, notifyCommand } = install(isGlobal);
    // Interactive mode - prompt for optional features
    handleStatusline(settings, true, (shouldInstallStatusline) => {
      handleNotifications(settings, true, (shouldInstallNotify) => {
        finishInstall(settingsPath, settings, statuslineCommand, notifyCommand, shouldInstallStatusline, shouldInstallNotify);
      });
    });
  });
}

// Main
if (hasGlobal && hasLocal) {
  console.error(`  ${yellow}Cannot specify both --global and --local${reset}`);
  process.exit(1);
} else if (explicitConfigDir && hasLocal) {
  console.error(`  ${yellow}Cannot use --config-dir with --local${reset}`);
  process.exit(1);
} else if (hasGlobal) {
  const { settingsPath, settings, statuslineCommand, notifyCommand } = install(true);
  // Non-interactive - respect flags
  handleStatusline(settings, false, (shouldInstallStatusline) => {
    handleNotifications(settings, false, (shouldInstallNotify) => {
      finishInstall(settingsPath, settings, statuslineCommand, notifyCommand, shouldInstallStatusline, shouldInstallNotify);
    });
  });
} else if (hasLocal) {
  const { settingsPath, settings, statuslineCommand, notifyCommand } = install(false);
  // Non-interactive - respect flags
  handleStatusline(settings, false, (shouldInstallStatusline) => {
    handleNotifications(settings, false, (shouldInstallNotify) => {
      finishInstall(settingsPath, settings, statuslineCommand, notifyCommand, shouldInstallStatusline, shouldInstallNotify);
    });
  });
} else {
  promptLocation();
}
