import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

async function read(relativePath) {
  return readFile(path.join(repositoryRoot, relativePath), "utf8");
}

function assertPinnedActions(content) {
  const uses = [...content.matchAll(/^\s*-?\s*uses:\s*([^\s]+)$/gmu)].map(
    (match) => match[1],
  );
  assert.equal(uses.length > 0, true);
  for (const value of uses) {
    assert.match(value, /^[^@\s]+@[a-f0-9]{40}$/u, `unpinned action: ${value}`);
  }
}

test("CI covers three operating systems and every local release gate", async () => {
  const content = await read(".github/workflows/ci.yml");
  assertPinnedActions(content);

  assert.match(content, /ubuntu-latest/u);
  assert.match(content, /macos-latest/u);
  assert.match(content, /windows-latest/u);
  assert.match(content, /npm run test:node/u);
  assert.match(content, /npm run test:posix/u);
  assert.match(content, /npm run test:authorization/u);
  assert.match(content, /npm run test:windows/u);
  assert.match(content, /shellcheck/u);
  assert.match(content, /PSScriptAnalyzer/u);
  assert.match(content, /package-plugin\.mjs/u);
  assert.match(content, /verify-upstream-release\.mjs/u);
  assert.match(content, /validate_plugin\.py/u);
  assert.match(content, /scan-source\.mjs/u);
  assert.doesNotMatch(content, /Telegram|TG_PASSWORD|session\.json/iu);
});

test("release workflow is source-only and version-gated", async () => {
  const content = await read(".github/workflows/release.yml");
  assertPinnedActions(content);

  assert.match(content, /tags:\s*\n\s*- ['"]?v\*/u);
  assert.match(content, /npm run package/u);
  assert.match(content, /tg-agent-plugin-.*\.tar\.gz/u);
  assert.match(content, /sha256/u);
  assert.match(content, /gh release create/u);
  assert.doesNotMatch(content, /gotd\/cli\/releases\/download|tg_0\./iu);
});
