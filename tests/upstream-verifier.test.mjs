import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { validateReleaseMetadata } from "../scripts/verify-upstream-release.mjs";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

test("upstream verifier requires checksum-file and GitHub digest agreement", async () => {
  const manifest = JSON.parse(
    await readFile(
      path.join(
        repositoryRoot,
        "plugins/tg-agent-plugin/config/release-manifest.json",
      ),
      "utf8",
    ),
  );
  const checksums = manifest.assets
    .map((asset) => `${asset.sha256}  ${asset.name}`)
    .join("\n");
  const release = {
    tag_name: manifest.upstream.tag,
    html_url: manifest.upstream.releaseUrl,
    assets: manifest.assets.map((asset) => ({
      name: asset.name,
      browser_download_url: asset.url,
      digest: asset.githubDigest,
    })),
  };

  assert.equal(validateReleaseMetadata(manifest, checksums, release), 6);
  assert.throws(() =>
    validateReleaseMetadata(
      manifest,
      checksums.replace(manifest.assets[0].sha256, "0".repeat(64)),
      release,
    ),
  );
  assert.throws(() =>
    validateReleaseMetadata(manifest, checksums, {
      ...release,
      assets: release.assets.map((asset, index) =>
        index === 0 ? { ...asset, digest: `sha256:${"0".repeat(64)}` } : asset,
      ),
    }),
  );
});
