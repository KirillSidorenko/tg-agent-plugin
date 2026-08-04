import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const scripts = path.join(repositoryRoot, "plugins/tg-agent-plugin/scripts");

const launcherPaths = {
  linux: path.join(scripts, "tg-login-linux.sh"),
  macos: path.join(scripts, "tg-login-macos.sh"),
  windows: path.join(scripts, "tg-login-windows.ps1"),
};

test("all platform launchers expose only secret-free login modes", async () => {
  const launchers = Object.fromEntries(
    await Promise.all(
      Object.entries(launcherPaths).map(async ([name, filePath]) => [
        name,
        await readFile(filePath, "utf8"),
      ]),
    ),
  );

  for (const [platform, content] of Object.entries(launchers)) {
    assert.match(content, /phone/u, `${platform} must support phone mode`);
    assert.match(content, /qr/u, `${platform} must support QR mode`);
    assert.match(content, /--phone=/u, `${platform} phone login must prompt locally`);
    assert.doesNotMatch(content, /Start-Transcript|\btee\b/u);
    assert.doesNotMatch(content, /--password(?:=|\s)/u);
    assert.doesNotMatch(content, /--phone[ =][+0-9]/u);
  }

  assert.match(launchers.windows, /Remove-Item\s+Env:TG_PASSWORD/u);
  assert.match(launchers.windows, /Start-Process/u);
  assert.doesNotMatch(
    launchers.windows,
    /\[string\]\s*\$(?:Phone|Password|Code|Token)\b/iu,
  );
});

test("Windows launcher initializes local config and invokes tg directly", async () => {
  const windows = await readFile(launcherPaths.windows, "utf8");
  assert.match(windows, /gotd\.cli\.yaml/u);
  assert.match(windows, /&\s+\$TgPath\s+init/u);
  assert.match(windows, /&\s+\$TgPath\s+login/u);
  assert.match(windows, /-NoProfile/u);
  assert.doesNotMatch(windows, /Invoke-Expression|cmd\.exe/iu);
});
