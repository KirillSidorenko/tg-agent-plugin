import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const skillsRoot = path.join(repositoryRoot, "plugins/tg-agent-plugin/skills");

const files = {
  telegram: {
    skill: "telegram/SKILL.md",
    agent: "telegram/agents/openai.yaml",
    commands: "telegram/references/commands.md",
    troubleshooting: "telegram/references/troubleshooting.md",
  },
  setup: {
    skill: "telegram-setup/SKILL.md",
    agent: "telegram-setup/agents/openai.yaml",
    authentication: "telegram-setup/references/authentication.md",
    platforms: "telegram-setup/references/platforms.md",
  },
};

async function skillFile(relativePath) {
  return readFile(path.join(skillsRoot, relativePath), "utf8");
}

function parseFrontmatter(content) {
  const normalized = content.replaceAll("\r\n", "\n");
  const match = normalized.match(/^---\n([\s\S]*?)\n---\n/u);
  assert.ok(match, "skill must start with YAML frontmatter");
  const entries = match[1]
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const separator = line.indexOf(":");
      assert.notEqual(separator, -1, `invalid frontmatter line: ${line}`);
      return [line.slice(0, separator), line.slice(separator + 1).trim()];
    });
  return Object.fromEntries(entries);
}

function validateSafetyText(content) {
  assert.doesNotMatch(content, /automatic(?:ally)?\s+(?:add\s+)?`?--yes`?/iu);
  assert.doesNotMatch(content, /tg\s+watch(?:\s+@\w+)?\s+-o\s+json\s*$/imu);
  assert.doesNotMatch(content, /paste[^.\n]*(?:code|password|token)[^.\n]*chat/iu);
  assert.doesNotMatch(content, /official Telegram (?:client|plugin|integration)/iu);
  assert.doesNotMatch(content, /(?:hosted|remote) (?:MCP|session)[^.\n]*supported/iu);
  assert.doesNotMatch(content, /\/Users\/|[A-Z]:\\Users\\/u);
}

test("both skills have minimal valid frontmatter and matching UI metadata", async () => {
  for (const [expectedName, relativePath] of [
    ["telegram", files.telegram.skill],
    ["telegram-setup", files.setup.skill],
  ]) {
    const content = await skillFile(relativePath);
    const frontmatter = parseFrontmatter(content);
    assert.deepEqual(Object.keys(frontmatter).sort(), ["description", "name"]);
    assert.equal(frontmatter.name, expectedName);
    assert.match(frontmatter.description, /Use when/iu);
    assert.equal(content.split(/\r?\n/u).length < 500, true);
    validateSafetyText(content);

    const agentPath =
      expectedName === "telegram" ? files.telegram.agent : files.setup.agent;
    const agent = await skillFile(agentPath);
    assert.match(agent, new RegExp(`\\$${expectedName}\\b`, "u"));
    assert.match(agent, /display_name:/u);
    assert.match(agent, /short_description:/u);
  }
});

test("telegram skill uses tg directly with bounded, minimal, safe workflows", async () => {
  const [skill, commands, troubleshooting] = await Promise.all([
    skillFile(files.telegram.skill),
    skillFile(files.telegram.commands),
    skillFile(files.telegram.troubleshooting),
  ]);
  const bundle = `${skill}\n${commands}\n${troubleshooting}`;

  assert.match(skill, /personal account/iu);
  assert.match(skill, /use .*`tg`.*direct/iu);
  assert.match(skill, /`-o json`/u);
  assert.match(skill, /stdout.*data.*stderr.*diagnostic/isu);
  assert.match(skill, /reuse one broad result/iu);
  assert.match(skill, /do not preflight every.*`whoami`/isu);
  assert.match(skill, /one targeted.*--help/isu);
  assert.match(skill, /sibling `telegram-setup`\s+skill/iu);

  assert.match(bundle, /ambiguous recipient/iu);
  assert.match(bundle, /confirmation immediately before/iu);
  assert.match(bundle, /never retry|never repeat/iu);
  assert.match(bundle, /verify once/iu);
  assert.match(bundle, /never overwrite/iu);
  assert.match(bundle, /`tg wait --timeout/iu);
  assert.match(bundle, /host.*(?:duration|event).*boundary/isu);
  assert.match(bundle, /terminate.*`tg watch`/isu);
  assert.match(bundle, /refuse.*bot/isu);
  validateSafetyText(bundle);
});

test("setup skill owns only pinned lifecycle and local authorization", async () => {
  const [skill, authentication, platforms] = await Promise.all([
    skillFile(files.setup.skill),
    skillFile(files.setup.authentication),
    skillFile(files.setup.platforms),
  ]);
  const bundle = `${skill}\n${authentication}\n${platforms}`;

  assert.match(skill, /installation.*authorization.*repair.*update/isu);
  assert.match(skill, /never route ordinary Telegram commands/iu);
  assert.match(skill, /explicit consent.*install/isu);
  assert.match(skill, /pinned/iu);
  assert.match(skill, /newer-unpinned/iu);
  assert.match(skill, /sibling `telegram` skill/iu);

  for (const action of [
    "status",
    "install",
    "repair",
    "check-update",
    "authorize",
    "verify-authorization",
  ]) {
    assert.match(bundle, new RegExp(`\\b${action}\\b`, "u"));
  }

  assert.match(bundle, /scripts\/tg-tool\.sh/u);
  assert.match(bundle, /scripts\\tg-tool\.ps1/u);
  assert.match(bundle, /`tg login --phone=`/u);
  assert.match(bundle, /QR login.*`tg login`/isu);
  assert.match(bundle, /do not poll/iu);
  assert.match(bundle, /https:\/\/github\.com\/gotd\/cli/u);
  assert.match(bundle, /only a wrapper/iu);
  assert.doesNotMatch(bundle, /install[^.\n]*newer-unpinned/iu);
  validateSafetyText(bundle);
});

test("unsafe skill fixtures are rejected by the static policy", () => {
  for (const fixture of [
    "Automatically add --yes for deletes.",
    "tg watch -o json",
    "Paste the login code into chat.",
    "This is an official Telegram client.",
    "A hosted MCP session is supported.",
    "Read /Users/example/session.json.",
  ]) {
    assert.throws(() => validateSafetyText(fixture));
  }
});
