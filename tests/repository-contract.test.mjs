import assert from "node:assert/strict";
import { readFile, readdir, stat } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

const requiredFiles = [
  ".gitignore",
  "AGENTS.md",
  "CHANGELOG.md",
  "CONTRIBUTING.md",
  "LICENSE",
  "README.md",
  "SECURITY.md",
  "THIRD_PARTY_NOTICES.md",
  "docs/architecture/project-map.md",
  "docs/plans/2026-08-04-tg-agent-plugin-implementation.md",
  "docs/specs/2026-08-04-tg-agent-plugin-design.md",
  "package.json",
];

const requiredDirectories = [
  ".github/workflows",
  "docs/runbooks",
  "plugins/tg-agent-plugin",
  "tests",
];

async function walk(relativeDirectory = "") {
  const absoluteDirectory = path.join(repositoryRoot, relativeDirectory);
  const entries = await readdir(absoluteDirectory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if ([".git", "node_modules"].includes(entry.name)) continue;
    const relativePath = path.join(relativeDirectory, entry.name);
    if (entry.isDirectory()) files.push(...(await walk(relativePath)));
    if (entry.isFile()) files.push(relativePath);
  }

  return files;
}

test("required repository files and directories exist", async () => {
  for (const relativePath of requiredFiles) {
    const file = await stat(path.join(repositoryRoot, relativePath));
    assert.equal(file.isFile(), true, `${relativePath} must be a file`);
  }

  for (const relativePath of requiredDirectories) {
    const directory = await stat(path.join(repositoryRoot, relativePath));
    assert.equal(
      directory.isDirectory(),
      true,
      `${relativePath} must be a directory`,
    );
  }
});

test("the initial repository version is 0.3.0", async () => {
  const packageJson = JSON.parse(
    await readFile(path.join(repositoryRoot, "package.json"), "utf8"),
  );
  assert.equal(packageJson.name, "tg-agent-plugin");
  assert.equal(packageJson.version, "0.3.0");
  assert.equal(packageJson.private, false);
});

test("public repository content is English", async () => {
  const textExtensions = new Set([
    ".json",
    ".md",
    ".mjs",
    ".ps1",
    ".sh",
    ".yaml",
    ".yml",
  ]);

  for (const relativePath of await walk()) {
    if (!textExtensions.has(path.extname(relativePath))) continue;
    const content = await readFile(path.join(repositoryRoot, relativePath), "utf8");
    assert.doesNotMatch(
      content,
      /[\u0400-\u04ff]/u,
      `${relativePath} contains Cyrillic text`,
    );
  }
});

test("the repository contains no bundled tg binary or session-like files", async () => {
  const forbiddenBasenames = new Set([
    ".env",
    "session.json",
    "telegram.db",
    "tg",
    "tg.exe",
  ]);
  const forbiddenExtensions = new Set([".key", ".session"]);

  for (const relativePath of await walk()) {
    const basename = path.basename(relativePath).toLowerCase();
    const extension = path.extname(basename);
    assert.equal(
      forbiddenBasenames.has(basename) || forbiddenExtensions.has(extension),
      false,
      `${relativePath} must not be committed`,
    );
  }
});
