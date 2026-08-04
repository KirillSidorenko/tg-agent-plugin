import assert from "node:assert/strict";
import { access, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repositoryUrl = "https://github.com/KirillSidorenko/tg-agent-plugin";

const requiredDocuments = [
  "README.md",
  "SECURITY.md",
  "THIRD_PARTY_NOTICES.md",
  "CONTRIBUTING.md",
  "CHANGELOG.md",
  "docs/runbooks/install-and-uninstall.md",
  "docs/runbooks/manual-platform-tests.md",
  "docs/runbooks/release.md",
  "docs/runbooks/troubleshooting.md",
  ".github/ISSUE_TEMPLATE/bug.yml",
  ".github/ISSUE_TEMPLATE/platform-install.yml",
  ".github/ISSUE_TEMPLATE/upstream-compatibility.yml",
  ".github/ISSUE_TEMPLATE/config.yml",
];

async function read(relativePath) {
  return readFile(path.join(repositoryRoot, relativePath), "utf8");
}

async function markdownFiles(relativeDirectory = "") {
  const directory = path.join(repositoryRoot, relativeDirectory);
  const entries = await readdir(directory, { withFileTypes: true });
  const result = [];
  for (const entry of entries) {
    if ([".git", "node_modules"].includes(entry.name)) continue;
    const relativePath = path.join(relativeDirectory, entry.name);
    if (entry.isDirectory()) result.push(...(await markdownFiles(relativePath)));
    if (entry.isFile() && path.extname(entry.name) === ".md") {
      result.push(relativePath);
    }
  }
  return result;
}

test("public documentation and issue-routing files exist", async () => {
  for (const relativePath of requiredDocuments) {
    await access(path.join(repositoryRoot, relativePath));
  }
});

test("README documents both hosts, local-only scope, lifecycle, and upstream", async () => {
  const readme = await read("README.md");

  assert.match(readme, /thin integration and safety layer/iu);
  assert.match(readme, /https:\/\/github\.com\/gotd\/cli/u);
  assert.match(readme, /https:\/\/github\.com\/ernado/u);
  assert.match(readme, /not affiliated with.*Telegram/isu);
  assert.match(readme, /personal accounts only/iu);
  assert.match(readme, /macOS.*Linux.*Windows/isu);
  assert.match(readme, /amd64.*arm64/isu);
  assert.match(readme, /gotd\/cli v0\.11\.0/u);

  assert.match(
    readme,
    /codex plugin marketplace add KirillSidorenko\/tg-agent-plugin/u,
  );
  assert.match(readme, /codex plugin add tg-agent-plugin@tg-agent/u);
  assert.match(
    readme,
    /claude plugin marketplace add KirillSidorenko\/tg-agent-plugin/u,
  );
  assert.match(readme, /claude plugin install tg-agent-plugin@tg-agent/u);

  assert.match(readme, /First local login/iu);
  assert.match(readme, /Never paste.*phone number.*code.*2FA/isu);
  assert.match(readme, /Updates/iu);
  assert.match(readme, /Uninstall/iu);
  assert.match(readme, /preserv.*configuration and sessions/isu);
  assert.match(readme, /Troubleshooting/iu);
  assert.match(readme, new RegExp(repositoryUrl.replaceAll("/", "\\/"), "u"));
});

test("security, attribution, contribution, and release policies are explicit", async () => {
  const [security, notices, contributing, changelog, release] = await Promise.all([
    read("SECURITY.md"),
    read("THIRD_PARTY_NOTICES.md"),
    read("CONTRIBUTING.md"),
    read("CHANGELOG.md"),
    read("docs/runbooks/release.md"),
  ]);

  assert.match(security, /private vulnerability/iu);
  assert.match(security, /phone numbers.*login codes.*QR tokens.*2FA/isu);
  assert.match(security, /checksum.*archive.*rollback/isu);
  assert.match(notices, /only an installation, workflow, and safety wrapper/iu);
  assert.match(notices, /Aleksandr Razumov/iu);
  assert.match(notices, /https:\/\/github\.com\/ernado/u);
  assert.match(notices, /does not.*redistribute.*binaries/isu);
  assert.match(contributing, /red\/green TDD/iu);
  assert.match(contributing, /Windows.*macOS.*Linux/isu);
  assert.match(changelog, /gotd\/cli v0\.11\.0/u);
  assert.match(release, /source-only/iu);
  assert.match(release, /no `tg` binaries/iu);
  assert.match(release, /manual.*macOS.*Linux.*Windows/isu);
});

test("runbooks own exact install, uninstall, troubleshooting, and platform gates", async () => {
  const [install, manual, troubleshooting] = await Promise.all([
    read("docs/runbooks/install-and-uninstall.md"),
    read("docs/runbooks/manual-platform-tests.md"),
    read("docs/runbooks/troubleshooting.md"),
  ]);

  assert.match(install, /Read when:/u);
  assert.match(install, /Do not read by default:/u);
  assert.match(install, /Fact owner:/u);
  assert.match(install, /codex plugin marketplace add/u);
  assert.match(install, /claude plugin marketplace add/u);
  assert.match(install, /preserv.*Telegram.*sessions/isu);
  assert.match(install, /optional.*managed.*executable/isu);

  assert.match(manual, /macOS amd64/iu);
  assert.match(manual, /macOS arm64/iu);
  assert.match(manual, /Linux amd64/iu);
  assert.match(manual, /Linux arm64/iu);
  assert.match(manual, /Windows amd64/iu);
  assert.match(manual, /Windows arm64/iu);
  assert.match(manual, /Claude Code/iu);
  assert.match(manual, /Codex/iu);
  assert.match(manual, /No credential value/iu);

  assert.match(troubleshooting, /checksum mismatch/iu);
  assert.match(troubleshooting, /stale backup/iu);
  assert.match(troubleshooting, /not-authorized/iu);
  assert.match(troubleshooting, /newer-unpinned/iu);
});

test("all local Markdown links resolve and public docs have no placeholders", async () => {
  for (const relativePath of await markdownFiles()) {
    const content = await read(relativePath);
    assert.doesNotMatch(content, /\b(?:TODO|TBD|FIXME)\b|OWNER\/|example\.com/iu);

    const links = content.matchAll(/\[[^\]]*\]\(([^)]+)\)/gu);
    for (const match of links) {
      const target = match[1].trim().replace(/^<|>$/gu, "");
      if (/^(?:https?:|mailto:|#)/u.test(target)) continue;
      const decoded = decodeURIComponent(target.split("#")[0]);
      const absolute = path.resolve(path.dirname(path.join(repositoryRoot, relativePath)), decoded);
      assert.equal(
        absolute.startsWith(`${repositoryRoot}${path.sep}`) || absolute === repositoryRoot,
        true,
        `${relativePath} links outside the repository: ${target}`,
      );
      await access(absolute);
    }
  }
});
