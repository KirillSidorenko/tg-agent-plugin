import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import {
  buildPackage,
  collectPackageEntries,
  validatePackageEntry,
} from "../scripts/package-plugin.mjs";

const execFileAsync = promisify(execFile);
const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

test("package allowlist contains only the nested source payload and notices", async () => {
  const entries = await collectPackageEntries(repositoryRoot);
  const names = entries.map((entry) => entry.archivePath);

  assert.equal(names.every((name) => name.startsWith("tg-agent-plugin/")), true);
  assert.equal(names.includes("tg-agent-plugin/.codex-plugin/plugin.json"), true);
  assert.equal(names.includes("tg-agent-plugin/.claude-plugin/plugin.json"), true);
  assert.equal(names.includes("tg-agent-plugin/LICENSE"), true);
  assert.equal(names.includes("tg-agent-plugin/THIRD_PARTY_NOTICES.md"), true);
  assert.equal(names.some((name) => name.endsWith("/skills/telegram/SKILL.md")), true);
  assert.equal(names.some((name) => name.endsWith("/scripts/tg-tool.ps1")), true);

  for (const name of names) {
    assert.doesNotMatch(name, /(?:^|\/)(?:tg|tg\.exe|session\.json|telegram\.db)$/iu);
    assert.doesNotMatch(name, /\.(?:bak|log|session|tmp)$/iu);
    assert.doesNotMatch(name, /(?:^|\/)\.env$/iu);
  }
});

test("package build is byte-for-byte reproducible and readable by tar", async () => {
  const temporary = await mkdtemp(path.join(tmpdir(), "tg-agent-package-test."));
  try {
    const first = path.join(temporary, "first.tar.gz");
    const second = path.join(temporary, "second.tar.gz");
    await buildPackage(repositoryRoot, first);
    await buildPackage(repositoryRoot, second);

    assert.deepEqual(await readFile(first), await readFile(second));
    const { stdout } = await execFileAsync("tar", ["-tzf", first]);
    const names = stdout.trim().split(/\r?\n/u);
    assert.equal(names.includes("tg-agent-plugin/.codex-plugin/plugin.json"), true);
    assert.equal(names.includes("tg-agent-plugin/LICENSE"), true);
    assert.equal(names.some((name) => /(?:^|\/)tg(?:\.exe)?$/iu.test(name)), false);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("unsafe package fixtures are rejected before archive creation", () => {
  for (const name of [
    "tg",
    "tg.exe",
    "session.json",
    "telegram.db",
    ".env",
    "state.session",
    "tool.bak",
    "trace.log",
    "../outside",
    "/absolute",
  ]) {
    assert.throws(() => validatePackageEntry(name, Buffer.from("text")));
  }

  assert.throws(() =>
    validatePackageEntry("bin/client", Buffer.from([0x7f, 0x45, 0x4c, 0x46])),
  );
  assert.throws(() =>
    validatePackageEntry("bin/client.exe", Buffer.from([0x4d, 0x5a, 0x90, 0x00])),
  );
});
