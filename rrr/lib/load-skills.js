/**
 * RRR Skills Loader
 *
 * Loads skills into agent context based on PLAN.md frontmatter or inference.
 * Called by execute-plan and execute-phase workflows.
 *
 * Usage:
 *   node load-skills.js <plan-path>
 *   node load-skills.js --infer <phase-content>
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Find skills directory (check local then global)
function findSkillsDir() {
  const localSkills = path.join(process.cwd(), '.claude', 'skills');
  const globalSkills = path.join(os.homedir(), '.claude', 'skills');

  if (fs.existsSync(localSkills)) return localSkills;
  if (fs.existsSync(globalSkills)) return globalSkills;

  // Fallback to source location (for development)
  const srcSkills = path.join(__dirname, '..', 'skills');
  if (fs.existsSync(srcSkills)) return srcSkills;

  return null;
}

// Load registry.json
function loadRegistry(skillsDir) {
  const registryPath = path.join(skillsDir, 'registry.json');
  if (!fs.existsSync(registryPath)) {
    console.error('Skills registry not found:', registryPath);
    return null;
  }
  return JSON.parse(fs.readFileSync(registryPath, 'utf8'));
}

// Parse YAML-like frontmatter from PLAN.md
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return {};

  const yaml = match[1];
  const result = {};

  // Parse skills array
  const skillsMatch = yaml.match(/skills:\s*\n((?:\s+-\s+.+\n?)+)/);
  if (skillsMatch) {
    result.skills = skillsMatch[1]
      .split('\n')
      .filter(line => line.trim().startsWith('-'))
      .map(line => line.replace(/^\s*-\s*/, '').trim())
      .filter(s => s);
  }

  // Parse skills_mode
  const modeMatch = yaml.match(/skills_mode:\s*(\w+)/);
  if (modeMatch) {
    result.skills_mode = modeMatch[1];
  }

  return result;
}

// Infer skills from content using registry rules
function inferSkills(content, registry) {
  const inferred = new Set();
  const contentLower = content.toLowerCase();

  for (const rule of registry.inference.rules) {
    for (const pattern of rule.patterns) {
      if (contentLower.includes(pattern.toLowerCase())) {
        inferred.add(rule.skill);
        break;
      }
    }
  }

  return Array.from(inferred);
}

// Resolve skill path and load content
function loadSkillContent(skillId, registry, skillsDir) {
  const skill = registry.skills[skillId];
  if (!skill) {
    console.warn(`Skill not found in registry: ${skillId}`);
    return null;
  }

  const skillPath = path.join(skillsDir, skill.path);
  if (!fs.existsSync(skillPath)) {
    console.warn(`Skill file not found: ${skillPath}`);
    return null;
  }

  const content = fs.readFileSync(skillPath, 'utf8');
  const lines = content.split('\n').length;

  return {
    id: skillId,
    content,
    lines,
    maxLines: skill.max_lines
  };
}

// Format skills for injection into agent prompt
function formatSkillsBlock(loadedSkills) {
  if (loadedSkills.length === 0) {
    return '';
  }

  let block = '<skills>\n';
  block += `<!-- ${loadedSkills.length} skill(s) loaded, ${loadedSkills.reduce((sum, s) => sum + s.lines, 0)} total lines -->\n\n`;

  for (const skill of loadedSkills) {
    block += `<!-- Skill: ${skill.id} (${skill.lines} lines) -->\n`;
    block += skill.content;
    block += '\n\n';
  }

  block += '</skills>';
  return block;
}

// Main function: load skills for a plan
function loadSkillsForPlan(planPath, options = {}) {
  const skillsDir = findSkillsDir();
  if (!skillsDir) {
    console.error('Skills directory not found');
    return { block: '', skills: [], totalLines: 0 };
  }

  const registry = loadRegistry(skillsDir);
  if (!registry) {
    return { block: '', skills: [], totalLines: 0 };
  }

  // Read plan content
  let planContent = '';
  if (fs.existsSync(planPath)) {
    planContent = fs.readFileSync(planPath, 'utf8');
  }

  // Parse frontmatter for explicit skills
  const frontmatter = parseFrontmatter(planContent);

  // Determine which skills to load
  let skillIds = frontmatter.skills || [];

  // If no explicit skills, try inference
  if (skillIds.length === 0 && options.inferContent) {
    skillIds = inferSkills(options.inferContent, registry);
  } else if (skillIds.length === 0) {
    skillIds = inferSkills(planContent, registry);
  }

  // Add default skills unless minimal mode
  if (frontmatter.skills_mode !== 'minimal') {
    for (const defaultSkill of registry.defaults.always_load) {
      if (!skillIds.includes(defaultSkill)) {
        skillIds.unshift(defaultSkill);
      }
    }
  }

  // Deduplicate
  skillIds = [...new Set(skillIds)];

  // Load skills respecting limits
  const loaded = [];
  let totalLines = 0;

  for (const id of skillIds) {
    if (loaded.length >= registry.limits.max_skills_per_plan) {
      console.warn(`Max skills reached (${registry.limits.max_skills_per_plan}), skipping: ${id}`);
      break;
    }

    const skill = loadSkillContent(id, registry, skillsDir);
    if (!skill) continue;

    if (totalLines + skill.lines > registry.limits.max_total_lines) {
      console.warn(`Line limit reached (${registry.limits.max_total_lines}), skipping: ${id}`);
      break;
    }

    loaded.push(skill);
    totalLines += skill.lines;
  }

  return {
    block: formatSkillsBlock(loaded),
    skills: loaded.map(s => s.id),
    totalLines
  };
}

// Log skills loaded (for execute workflows)
function logSkillsLoaded(result, planPath) {
  const logDir = path.join(process.cwd(), '.planning', 'logs');
  if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
  }

  const timestamp = new Date().toISOString();
  const logFile = path.join(logDir, `skills_${Date.now()}.log`);
  const logEntry = `[${timestamp}] Plan: ${planPath}
[${timestamp}] Skills loaded: ${result.skills.join(', ') || 'none'} (${result.totalLines} lines)
[${timestamp}] Total: ${result.totalLines} lines / 1000 max
`;

  fs.writeFileSync(logFile, logEntry);
  return logFile;
}

// CLI interface
if (require.main === module) {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log('Usage: node load-skills.js <plan-path>');
    console.log('       node load-skills.js --infer <content>');
    console.log('       node load-skills.js --list');
    process.exit(1);
  }

  if (args[0] === '--list') {
    const skillsDir = findSkillsDir();
    if (skillsDir) {
      const registry = loadRegistry(skillsDir);
      if (registry) {
        console.log('Available skills:\n');
        for (const [id, skill] of Object.entries(registry.skills)) {
          console.log(`  ${id}`);
          console.log(`    Tags: ${skill.tags.join(', ')}`);
          console.log(`    Max lines: ${skill.max_lines}`);
          console.log('');
        }
      }
    }
    process.exit(0);
  }

  if (args[0] === '--infer') {
    const content = args.slice(1).join(' ');
    const skillsDir = findSkillsDir();
    const registry = loadRegistry(skillsDir);
    if (registry) {
      const inferred = inferSkills(content, registry);
      console.log('Inferred skills:', inferred.join(', ') || 'none');
    }
    process.exit(0);
  }

  const planPath = args[0];
  const result = loadSkillsForPlan(planPath);

  console.log(`Skills loaded: ${result.skills.join(', ') || 'none'}`);
  console.log(`Total lines: ${result.totalLines}`);

  if (args.includes('--output')) {
    console.log('\n--- Skills Block ---\n');
    console.log(result.block);
  }
}

module.exports = {
  loadSkillsForPlan,
  inferSkills,
  findSkillsDir,
  loadRegistry,
  logSkillsLoaded
};
