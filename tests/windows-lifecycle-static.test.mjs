import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const toolPath = path.join(
  repositoryRoot,
  "plugins/tg-agent-plugin/scripts/tg-tool.ps1",
);
const testPath = path.join(repositoryRoot, "tests/windows-lifecycle.Tests.ps1");

test("Windows lifecycle mirrors the approved pinned local contract", async () => {
  const content = await readFile(toolPath, "utf8");

  for (const action of [
    "status",
    "install",
    "repair",
    "check-update",
    "authorize",
    "verify-authorization",
  ]) {
    assert.match(content, new RegExp(`'${action}'`, "u"));
  }

  assert.match(content, /release-manifest\.json/u);
  assert.match(content, /ConvertFrom-Json/u);
  assert.match(content, /https:\/\/github\.com\/gotd\/cli\/releases\/download\//u);
  assert.match(content, /Get-FileHash/u);
  assert.match(content, /tar\.exe.*-tzf/u);
  assert.match(content, /tar\.exe.*-tvzf/u);
  assert.match(content, /tg\.exe\.bak/u);
  assert.match(content, /Rollback-Replacement/u);
  assert.match(content, /Move-Item/u);
  assert.match(content, /TGAgentPlugin/u);
  assert.match(content, /Programs[\\/]tg[\\/]tg\.exe/u);
  assert.match(content, /Remove-Item\s+Env:TG_PASSWORD/u);

  assert.doesNotMatch(content, /Invoke-Expression|Start-Transcript/iu);
  assert.doesNotMatch(content, /Program Files|RunAs|Verb\s+RunAs/iu);
  assert.doesNotMatch(content, /Remove-Item[^\n]*(?:session|gotd\.cli)/iu);
  assert.doesNotMatch(content, /releases\/latest[^\n]*OutFile/iu);
});

test("Windows harness covers lifecycle and security negatives without Pester", async () => {
  const content = await readFile(testPath, "utf8");

  for (const evidence of [
    "checksum mismatch",
    "parent traversal",
    "absolute path",
    "symbolic link",
    "hard link",
    "duplicate executable",
    "rollback",
    "newer-unpinned",
    "stale backup",
  ]) {
    assert.match(content.toLowerCase(), new RegExp(evidence.replace(" ", "[ -]"), "u"));
  }

  assert.match(content, /Assert-Throws/u);
  assert.match(content, /Assert-Equal/u);
  assert.doesNotMatch(content, /Describe\s|It\s+['"]/u);
});
