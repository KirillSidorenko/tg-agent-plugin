import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const manifestPath = path.join(
  repositoryRoot,
  "plugins/tg-agent-plugin/config/release-manifest.json",
);

const upstreamRepository = "https://github.com/gotd/cli";
const tag = "v0.11.0";
const version = "0.11.0";
const releaseBase = `${upstreamRepository}/releases/download/${tag}`;
const expectedPlatforms = new Map([
  [
    "darwin/amd64",
    {
      name: "tg_0.11.0_darwin_amd64.tar.gz",
      sha256: "ace7c122796053662781ce60e736930eb4c25c363c7801407aa3566d15cdcb4a",
    },
  ],
  [
    "darwin/arm64",
    {
      name: "tg_0.11.0_darwin_arm64.tar.gz",
      sha256: "9e72b09903c69e0a3854dfdac722bd44b99d4f2f5b9721e28bf1fa201f2b62f7",
    },
  ],
  [
    "linux/amd64",
    {
      name: "tg_0.11.0_linux_amd64.tar.gz",
      sha256: "3510fcba55aadea2ca1b630766d37fb6dba30c4ab249f9d3adacc60ca75d43c8",
    },
  ],
  [
    "linux/arm64",
    {
      name: "tg_0.11.0_linux_arm64.tar.gz",
      sha256: "d26f11be2adfc30c9a9f10aa8f2930d736f83468f452bf814963b1d917c5474b",
    },
  ],
  [
    "windows/amd64",
    {
      name: "tg_0.11.0_windows_amd64.tar.gz",
      sha256: "b5b3dab350c073d4058805c3327e849f8ee8cccb6ecd28e668838d10a0be33de",
    },
  ],
  [
    "windows/arm64",
    {
      name: "tg_0.11.0_windows_arm64.tar.gz",
      sha256: "da86bfff51891b0f8d6e8d44e60b8e692a34ebd24cb3a6ee56aa661a55d3a482",
    },
  ],
]);
const expectedSmokeCommands = [
  { name: "root-help", args: ["--help"] },
  { name: "whoami-help", args: ["whoami", "--help"] },
  { name: "login-help", args: ["login", "--help"] },
];

function validateReleaseManifest(manifest) {
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.upstream.repository, upstreamRepository);
  assert.equal(manifest.upstream.tag, tag);
  assert.equal(manifest.upstream.version, version);
  assert.equal(
    manifest.upstream.releaseUrl,
    `${upstreamRepository}/releases/tag/${tag}`,
  );
  assert.equal(
    manifest.upstream.checksumsUrl,
    `${releaseBase}/checksums.txt`,
  );
  assert.deepEqual(manifest.smokeCommands, expectedSmokeCommands);
  assert.equal(manifest.assets.length, expectedPlatforms.size);

  const actualPlatforms = new Set();
  for (const asset of manifest.assets) {
    const platform = `${asset.os}/${asset.arch}`;
    assert.equal(expectedPlatforms.has(platform), true, `unsupported ${platform}`);
    assert.equal(actualPlatforms.has(platform), false, `duplicate ${platform}`);
    actualPlatforms.add(platform);

    const expected = expectedPlatforms.get(platform);
    assert.equal(asset.name, expected.name);
    assert.equal(asset.url, `${releaseBase}/${expected.name}`);
    assert.match(asset.sha256, /^[a-f0-9]{64}$/u);
    assert.equal(asset.sha256, expected.sha256);
    assert.equal(asset.githubDigest, `sha256:${asset.sha256}`);
  }

  assert.deepEqual(actualPlatforms, new Set(expectedPlatforms.keys()));
}

test("release manifest pins the tested gotd/cli v0.11.0 asset set", async () => {
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  validateReleaseManifest(manifest);
});

test("release manifest validation rejects malformed compatibility data", () => {
  const valid = {
    schemaVersion: 1,
    upstream: {
      repository: upstreamRepository,
      tag,
      version,
      releaseUrl: `${upstreamRepository}/releases/tag/${tag}`,
      checksumsUrl: `${releaseBase}/checksums.txt`,
    },
    smokeCommands: expectedSmokeCommands,
    assets: [...expectedPlatforms].map(([platform, expected]) => {
      const [os, arch] = platform.split("/");
      return {
        os,
        arch,
        name: expected.name,
        url: `${releaseBase}/${expected.name}`,
        sha256: expected.sha256,
        githubDigest: `sha256:${expected.sha256}`,
      };
    }),
  };

  const withAsset = (assetPatch) => ({
    ...valid,
    assets: [
      { ...valid.assets[0], ...assetPatch },
      ...valid.assets.slice(1),
    ],
  });

  assert.throws(() => validateReleaseManifest(withAsset({ sha256: "missing" })));
  assert.throws(() =>
    validateReleaseManifest(
      withAsset({ url: "https://example.com/tg_0.11.0_darwin_amd64.tar.gz" }),
    ),
  );
  assert.throws(() => validateReleaseManifest(withAsset({ os: "freebsd" })));
  assert.throws(() =>
    validateReleaseManifest({
      ...valid,
      upstream: { ...valid.upstream, tag: "v0.12.0" },
    }),
  );
  assert.throws(() =>
    validateReleaseManifest({
      ...valid,
      assets: [valid.assets[0], valid.assets[0], ...valid.assets.slice(2)],
    }),
  );
});
