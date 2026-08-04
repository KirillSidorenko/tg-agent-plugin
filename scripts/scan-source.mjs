#!/usr/bin/env node
import { lstat, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const ignoredDirectories = new Set([".git", "dist", "node_modules"]);
const forbiddenArtifactNames = new Set([
  ".env",
  "session.json",
  "telegram.db",
  "tg",
  "tg.exe",
]);

const contentRules = [
  {
    rule: "private-key",
    pattern: /-----BEGIN(?: [A-Z0-9]+)* PRIVATE KEY-----/u,
  },
  {
    rule: "telegram-bot-token",
    pattern: /\b\d{8,12}:[A-Za-z0-9_-]{35}\b/u,
  },
  {
    rule: "credential-assignment",
    pattern:
      /\b(?:APP_ID|APP_HASH|TG_PASSWORD|BOT_TOKEN)\s*=\s*["']?[A-Za-z0-9_+\/]{12,}/u,
  },
  {
    rule: "login-phone-number",
    pattern: /(?:^|[^\d])\+\d{10,15}(?:$|[^\d])/u,
  },
];

function binaryRule(content) {
  const magic = content.subarray(0, 4).toString("hex");
  if (magic === "7f454c46" || magic.startsWith("4d5a")) {
    return "executable-binary";
  }
  if (["cafebabe", "cefaedfe", "cffaedfe", "feedface", "feedfacf"].includes(magic)) {
    return "executable-binary";
  }
  if (content.includes(0)) return "binary-content";
  return null;
}

async function walk(root, relativeDirectory, findings) {
  const directory = path.join(root, relativeDirectory);
  const entries = await readdir(directory, { withFileTypes: true });
  entries.sort((left, right) => left.name.localeCompare(right.name));

  for (const entry of entries) {
    if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue;
    const relativePath = path.join(relativeDirectory, entry.name);
    const absolutePath = path.join(root, relativePath);
    const metadata = await lstat(absolutePath);

    if (metadata.isSymbolicLink()) {
      findings.push({ path: relativePath, rule: "symbolic-link" });
      continue;
    }
    if (metadata.isDirectory()) {
      await walk(root, relativePath, findings);
      continue;
    }
    if (!metadata.isFile()) {
      findings.push({ path: relativePath, rule: "unsupported-artifact" });
      continue;
    }

    const basename = entry.name.toLowerCase();
    if (forbiddenArtifactNames.has(basename)) {
      findings.push({
        path: relativePath,
        rule: basename === "tg" || basename === "tg.exe" ? "executable-binary" : "session-artifact",
      });
    }

    const content = await readFile(absolutePath);
    const detectedBinaryRule = binaryRule(content);
    if (detectedBinaryRule) {
      findings.push({ path: relativePath, rule: detectedBinaryRule });
      continue;
    }
    const text = content.toString("utf8");
    for (const { rule, pattern } of contentRules) {
      if (pattern.test(text)) findings.push({ path: relativePath, rule });
    }
  }
}

export async function scanSourceTree(root) {
  const findings = [];
  await walk(path.resolve(root), "", findings);
  return findings;
}

async function main() {
  const root = path.resolve(process.argv[2] ?? ".");
  const findings = await scanSourceTree(root);
  if (findings.length > 0) {
    for (const finding of findings) {
      process.stderr.write(`${finding.rule}: ${finding.path}\n`);
    }
    process.exitCode = 1;
    return;
  }
  process.stdout.write(`Source security scan passed: ${root}\n`);
}

if (
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url
) {
  await main();
}
