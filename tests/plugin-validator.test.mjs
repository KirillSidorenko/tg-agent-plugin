import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const validator = path.join(repositoryRoot, "scripts/validate_plugin.py");

test("dependency-free validator accepts the payload and rejects placeholders", async () => {
  const valid = spawnSync(
    "python3",
    [validator, path.join(repositoryRoot, "plugins/tg-agent-plugin")],
    { encoding: "utf8" },
  );
  assert.equal(valid.status, 0, valid.stderr || valid.stdout);

  const temporary = await mkdtemp(path.join(tmpdir(), "tg-agent-validator-test."));
  try {
    await mkdir(path.join(temporary, ".codex-plugin"), { recursive: true });
    await mkdir(path.join(temporary, "skills/bad"), { recursive: true });
    await writeFile(
      path.join(temporary, ".codex-plugin/plugin.json"),
      JSON.stringify({
        name: "bad-plugin",
        version: "1.0.0",
        description: "[TODO: replace]",
        author: { name: "Test" },
        interface: {
          displayName: "Bad",
          shortDescription: "Bad placeholder plugin metadata",
          longDescription: "Bad placeholder plugin metadata for validation.",
          developerName: "Test",
          category: "Productivity",
          capabilities: [],
        },
      }),
    );
    await writeFile(
      path.join(temporary, "skills/bad/SKILL.md"),
      "---\nname: bad\ndescription: Use when testing.\n---\n\n# Bad\n",
    );
    const invalid = spawnSync("python3", [validator, temporary], {
      encoding: "utf8",
    });
    assert.notEqual(invalid.status, 0);
    assert.match(`${invalid.stdout}\n${invalid.stderr}`, /placeholder/iu);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});
