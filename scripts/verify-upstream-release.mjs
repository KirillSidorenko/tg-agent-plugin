#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

function checksumMap(text) {
  const result = new Map();
  for (const line of text.split(/\r?\n/u)) {
    if (!line.trim()) continue;
    const match = line.match(/^([a-f0-9]{64})\s+\*?([^\s]+)$/u);
    if (!match) throw new Error(`Malformed checksum line: ${line}`);
    result.set(match[2], match[1]);
  }
  return result;
}

export function validateReleaseMetadata(manifest, checksumsText, release) {
  if (release.tag_name !== manifest.upstream.tag) {
    throw new Error("GitHub release tag does not match the pinned tag");
  }
  if (release.html_url !== manifest.upstream.releaseUrl) {
    throw new Error("GitHub release URL does not match the pinned release URL");
  }

  const checksums = checksumMap(checksumsText);
  const assets = new Map(release.assets.map((asset) => [asset.name, asset]));
  for (const expected of manifest.assets) {
    if (checksums.get(expected.name) !== expected.sha256) {
      throw new Error(`Checksum-file mismatch for ${expected.name}`);
    }
    const actual = assets.get(expected.name);
    if (!actual) throw new Error(`GitHub release asset is missing: ${expected.name}`);
    if (actual.browser_download_url !== expected.url) {
      throw new Error(`GitHub asset URL mismatch for ${expected.name}`);
    }
    if (actual.digest !== expected.githubDigest) {
      throw new Error(`GitHub asset digest mismatch for ${expected.name}`);
    }
  }
  return manifest.assets.length;
}

async function fetchText(url, headers = {}) {
  const response = await fetch(url, { headers, redirect: "follow" });
  if (!response.ok) throw new Error(`Request failed (${response.status}): ${url}`);
  return response.text();
}

async function main() {
  const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const manifest = JSON.parse(
    await readFile(
      path.join(
        repositoryRoot,
        "plugins/tg-agent-plugin/config/release-manifest.json",
      ),
      "utf8",
    ),
  );
  const checksums = await fetchText(manifest.upstream.checksumsUrl, {
    "User-Agent": "tg-agent-plugin",
  });
  const release = JSON.parse(
    await fetchText(
      `https://api.github.com/repos/gotd/cli/releases/tags/${manifest.upstream.tag}`,
      {
        Accept: "application/vnd.github+json",
        "User-Agent": "tg-agent-plugin",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    ),
  );
  const count = validateReleaseMetadata(manifest, checksums, release);
  process.stdout.write(`Verified ${count} pinned gotd/cli release assets.\n`);
}

if (
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url
) {
  await main();
}
