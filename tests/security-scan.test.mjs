import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { scanSourceTree } from "../scripts/scan-source.mjs";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

test("repository source tree contains no credential or binary artifacts", async () => {
  const findings = await scanSourceTree(repositoryRoot);
  assert.deepEqual(findings, []);
});

test("scanner rejects representative secret and session artifacts", async () => {
  const fixture = await mkdtemp(path.join(os.tmpdir(), "tg-agent-security-"));
  await mkdir(path.join(fixture, "nested"));
  await writeFile(
    path.join(fixture, "nested", "credential.txt"),
    ["-----BEGIN OPENSSH ", "PRIVATE KEY-----"].join(""),
  );
  await writeFile(path.join(fixture, "session.json"), "{}\n");
  await writeFile(path.join(fixture, "tg"), Buffer.from([0x7f, 0x45, 0x4c, 0x46]));

  const findings = await scanSourceTree(fixture);
  assert.equal(findings.some((finding) => finding.rule === "private-key"), true);
  assert.equal(findings.some((finding) => finding.rule === "session-artifact"), true);
  assert.equal(findings.some((finding) => finding.rule === "executable-binary"), true);
});
