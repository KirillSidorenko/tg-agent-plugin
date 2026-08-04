import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const pluginRoot = path.join(repositoryRoot, "plugins/tg-agent-plugin");
const descriptor =
  "Unofficial local agent integration for Telegram, powered by gotd/cli.";

const manifestPaths = {
  claude: path.join(pluginRoot, ".claude-plugin/plugin.json"),
  codex: path.join(pluginRoot, ".codex-plugin/plugin.json"),
};
const marketplacePaths = {
  claude: path.join(repositoryRoot, ".claude-plugin/marketplace.json"),
  codex: path.join(repositoryRoot, ".agents/plugins/marketplace.json"),
};

async function readJson(filePath) {
  return JSON.parse(await readFile(filePath, "utf8"));
}

function assertSafeRelativePath(value, label) {
  assert.equal(typeof value, "string", `${label} must be a string`);
  assert.equal(value.startsWith("./"), true, `${label} must start with ./`);
  assert.equal(path.posix.isAbsolute(value), false, `${label} must be relative`);
  assert.equal(
    value.split("/").includes(".."),
    false,
    `${label} must not traverse outside its root`,
  );
}

function validateCodexManifest(manifest) {
  const allowedFields = new Set([
    "author",
    "description",
    "homepage",
    "interface",
    "keywords",
    "license",
    "name",
    "repository",
    "skills",
    "version",
  ]);
  for (const field of Object.keys(manifest)) {
    assert.equal(allowedFields.has(field), true, `unsupported Codex field: ${field}`);
  }

  assert.equal(manifest.name, "tg-agent-plugin");
  assert.match(manifest.version, /^\d+\.\d+\.\d+$/u);
  assert.equal(manifest.description, descriptor);
  assert.equal(manifest.author?.name, "TG Agent Plugin contributors");
  assert.equal(manifest.author?.url, "https://github.com/KirillSidorenko");
  assert.equal(manifest.homepage, "https://github.com/KirillSidorenko/tg-agent-plugin#readme");
  assert.equal(manifest.repository, "https://github.com/KirillSidorenko/tg-agent-plugin");
  assert.equal(manifest.license, "MIT");
  assertSafeRelativePath(manifest.skills, "Codex skills path");
  assert.equal(manifest.interface?.displayName, "TG Agent");
  assert.equal(manifest.interface?.developerName, "TG Agent Plugin contributors");
  assert.equal(manifest.interface?.category, "Productivity");
  assert.deepEqual(manifest.interface?.capabilities, ["Read", "Write"]);
  assert.equal(manifest.interface?.defaultPrompt.length <= 3, true);
  assertSafeRelativePath(manifest.interface?.composerIcon, "composer icon");
  assertSafeRelativePath(manifest.interface?.logo, "logo");
}

function validateClaudeManifest(manifest) {
  const allowedFields = new Set([
    "author",
    "description",
    "homepage",
    "keywords",
    "license",
    "name",
    "repository",
    "version",
  ]);
  for (const field of Object.keys(manifest)) {
    assert.equal(allowedFields.has(field), true, `unsupported Claude field: ${field}`);
  }

  assert.equal(manifest.name, "tg-agent-plugin");
  assert.match(manifest.version, /^\d+\.\d+\.\d+$/u);
  assert.equal(manifest.description, descriptor);
  assert.equal(manifest.author?.name, "TG Agent Plugin contributors");
  assert.equal(manifest.author?.url, "https://github.com/KirillSidorenko");
  assert.equal(manifest.homepage, "https://github.com/KirillSidorenko/tg-agent-plugin#readme");
  assert.equal(manifest.repository, "https://github.com/KirillSidorenko/tg-agent-plugin");
  assert.equal(manifest.license, "MIT");
}

function validateCodexMarketplace(marketplace) {
  assert.equal(marketplace.name, "tg-agent");
  assert.equal(marketplace.interface?.displayName, "TG Agent");
  assert.equal(marketplace.plugins.length, 1);
  const entry = marketplace.plugins[0];
  assert.equal(entry.name, "tg-agent-plugin");
  assert.equal(entry.source?.source, "local");
  assertSafeRelativePath(entry.source?.path, "Codex marketplace source");
  assert.equal(entry.source.path, "./plugins/tg-agent-plugin");
  assert.deepEqual(entry.policy, {
    installation: "AVAILABLE",
    authentication: "ON_INSTALL",
  });
  assert.equal(entry.category, "Productivity");
}

function validateClaudeMarketplace(marketplace) {
  assert.equal(marketplace.name, "tg-agent");
  assert.equal(marketplace.description, descriptor);
  assert.equal(marketplace.owner?.name, "TG Agent Plugin contributors");
  assert.equal(marketplace.plugins.length, 1);
  const entry = marketplace.plugins[0];
  assert.equal(entry.name, "tg-agent-plugin");
  assertSafeRelativePath(entry.source, "Claude marketplace source");
  assert.equal(entry.source, "./plugins/tg-agent-plugin");
  assert.equal(entry.description, descriptor);
  assert.equal(entry.version, "0.3.0");
}

test("Claude Code and Codex manifests describe one shared plugin", async () => {
  const [claude, codex] = await Promise.all([
    readJson(manifestPaths.claude),
    readJson(manifestPaths.codex),
  ]);

  validateClaudeManifest(claude);
  validateCodexManifest(codex);
  assert.equal(claude.name, codex.name);
  assert.equal(claude.version, codex.version);
  assert.equal(claude.description, codex.description);
});

test("both marketplaces resolve the same nested payload", async () => {
  const [claude, codex] = await Promise.all([
    readJson(marketplacePaths.claude),
    readJson(marketplacePaths.codex),
  ]);

  validateClaudeMarketplace(claude);
  validateCodexMarketplace(codex);
  assert.equal(claude.plugins[0].name, codex.plugins[0].name);
  assert.equal(claude.plugins[0].source, codex.plugins[0].source.path);
});

test("manifest assets exist inside the shared payload", async () => {
  const codex = await readJson(manifestPaths.codex);
  for (const assetPath of [
    codex.interface.composerIcon,
    codex.interface.logo,
  ]) {
    assertSafeRelativePath(assetPath, "manifest asset");
    const asset = await stat(path.join(pluginRoot, assetPath));
    assert.equal(asset.isFile(), true);
  }
});

test("validators reject unsafe or inconsistent fixture data", () => {
  const codexManifest = {
    name: "tg-agent-plugin",
    version: "0.3.0",
    description: descriptor,
    author: { name: "TG Agent Plugin contributors" },
    license: "MIT",
    keywords: ["telegram", "agent"],
    skills: "./skills/",
    interface: {
      displayName: "TG Agent",
      developerName: "TG Agent Plugin contributors",
      category: "Productivity",
      capabilities: ["Read", "Write"],
      defaultPrompt: ["Read my latest Telegram messages."],
      composerIcon: "./assets/tg-agent-mark.svg",
      logo: "./assets/tg-agent-mark.svg",
    },
  };
  const codexMarketplace = {
    name: "tg-agent",
    interface: { displayName: "TG Agent" },
    plugins: [
      {
        name: "tg-agent-plugin",
        source: { source: "local", path: "./plugins/tg-agent-plugin" },
        policy: { installation: "AVAILABLE", authentication: "ON_INSTALL" },
        category: "Productivity",
      },
    ],
  };

  assert.throws(() =>
    validateCodexManifest({ ...codexManifest, unsupported: true }),
  );
  assert.throws(() =>
    validateCodexManifest({
      ...codexManifest,
      skills: "../outside",
    }),
  );
  assert.throws(() =>
    validateCodexManifest({
      ...codexManifest,
      interface: {
        ...codexManifest.interface,
        defaultPrompt: ["one", "two", "three", "four"],
      },
    }),
  );
  assert.throws(() =>
    validateCodexMarketplace({
      ...codexMarketplace,
      plugins: [{ ...codexMarketplace.plugins[0], policy: undefined }],
    }),
  );
  assert.notEqual(codexManifest.version, "0.3.1");
});
