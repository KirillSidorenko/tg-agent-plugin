#!/usr/bin/env node
import { createHash } from "node:crypto";
import { lstat, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { gzipSync } from "node:zlib";

const allowedExtensions = new Set([
  ".json",
  ".md",
  ".ps1",
  ".sh",
  ".svg",
  ".yaml",
  ".yml",
]);
const forbiddenNames = new Set([
  ".env",
  "session.json",
  "telegram.db",
  "tg",
  "tg.exe",
]);
const forbiddenExtensions = new Set([".bak", ".key", ".log", ".session", ".tmp"]);

export function validatePackageEntry(relativePath, content) {
  const normalized = relativePath.replaceAll(path.sep, "/");
  if (
    normalized.startsWith("/") ||
    normalized.includes("\\") ||
    normalized.split("/").includes("..") ||
    /[\u0000-\u001f]/u.test(normalized)
  ) {
    throw new Error(`Unsafe package path: ${relativePath}`);
  }

  const basename = path.posix.basename(normalized).toLowerCase();
  const extension = path.posix.extname(basename);
  if (forbiddenNames.has(basename) || forbiddenExtensions.has(extension)) {
    throw new Error(`Forbidden package entry: ${relativePath}`);
  }
  if (basename !== "license" && !allowedExtensions.has(extension)) {
    throw new Error(`Unsupported source file type: ${relativePath}`);
  }
  if (content.length > 1024 * 1024) {
    throw new Error(`Unexpectedly large package entry: ${relativePath}`);
  }
  if (content.includes(0)) {
    throw new Error(`Binary content is not allowed: ${relativePath}`);
  }

  const magic = content.subarray(0, 4).toString("hex");
  if (
    magic === "7f454c46" ||
    magic.startsWith("4d5a") ||
    ["cafebabe", "cefaedfe", "cffaedfe", "feedface", "feedfacf"].includes(magic)
  ) {
    throw new Error(`Executable binary is not allowed: ${relativePath}`);
  }
}

async function collectDirectory(sourceRoot, relativeDirectory = "") {
  const directory = path.join(sourceRoot, relativeDirectory);
  const entries = await readdir(directory, { withFileTypes: true });
  const result = [];

  for (const entry of entries) {
    const relativePath = path.join(relativeDirectory, entry.name);
    const absolutePath = path.join(sourceRoot, relativePath);
    const metadata = await lstat(absolutePath);
    if (metadata.isSymbolicLink()) {
      throw new Error(`Symbolic links are not allowed in the package: ${relativePath}`);
    }
    if (metadata.isDirectory()) {
      result.push(...(await collectDirectory(sourceRoot, relativePath)));
    } else if (metadata.isFile()) {
      const content = await readFile(absolutePath);
      validatePackageEntry(relativePath, content);
      result.push({ relativePath, sourcePath: absolutePath, content });
    } else {
      throw new Error(`Unsupported filesystem entry: ${relativePath}`);
    }
  }

  return result;
}

export async function collectPackageEntries(repositoryRoot) {
  const pluginRoot = path.join(repositoryRoot, "plugins/tg-agent-plugin");
  const pluginEntries = await collectDirectory(pluginRoot);
  const rootEntries = [];
  for (const relativePath of ["LICENSE", "THIRD_PARTY_NOTICES.md"]) {
    const sourcePath = path.join(repositoryRoot, relativePath);
    const content = await readFile(sourcePath);
    validatePackageEntry(relativePath, content);
    rootEntries.push({ relativePath, sourcePath, content });
  }

  return [...pluginEntries, ...rootEntries]
    .map((entry) => ({
      ...entry,
      archivePath: `tg-agent-plugin/${entry.relativePath.replaceAll(path.sep, "/")}`,
      mode: entry.relativePath.endsWith(".sh") ? 0o755 : 0o644,
    }))
    .sort((left, right) => left.archivePath.localeCompare(right.archivePath));
}

function writeString(buffer, offset, length, value) {
  const encoded = Buffer.from(value, "utf8");
  if (encoded.length > length) throw new Error(`TAR field is too long: ${value}`);
  encoded.copy(buffer, offset);
}

function writeOctal(buffer, offset, length, value) {
  const encoded = value.toString(8).padStart(length - 1, "0");
  if (encoded.length > length - 1) throw new Error("TAR numeric field overflow");
  buffer.write(encoded, offset, length - 1, "ascii");
  buffer[offset + length - 1] = 0;
}

function tarHeader(entry) {
  const header = Buffer.alloc(512, 0);
  writeString(header, 0, 100, entry.archivePath);
  writeOctal(header, 100, 8, entry.mode);
  writeOctal(header, 108, 8, 0);
  writeOctal(header, 116, 8, 0);
  writeOctal(header, 124, 12, entry.content.length);
  writeOctal(header, 136, 12, 0);
  header.fill(0x20, 148, 156);
  header[156] = "0".charCodeAt(0);
  writeString(header, 257, 6, "ustar\0");
  writeString(header, 263, 2, "00");
  writeString(header, 265, 32, "root");
  writeString(header, 297, 32, "root");

  const checksum = header.reduce((sum, byte) => sum + byte, 0);
  const encoded = checksum.toString(8).padStart(6, "0");
  header.write(encoded, 148, 6, "ascii");
  header[154] = 0;
  header[155] = 0x20;
  return header;
}

function createTar(entries) {
  const chunks = [];
  for (const entry of entries) {
    chunks.push(tarHeader(entry), entry.content);
    const remainder = entry.content.length % 512;
    if (remainder !== 0) chunks.push(Buffer.alloc(512 - remainder, 0));
  }
  chunks.push(Buffer.alloc(1024, 0));
  return Buffer.concat(chunks);
}

export async function buildPackage(repositoryRoot, outputPath) {
  const entries = await collectPackageEntries(repositoryRoot);
  const archive = gzipSync(createTar(entries), { level: 9, mtime: 0 });
  await mkdir(path.dirname(outputPath), { recursive: true });
  await writeFile(outputPath, archive);
  return {
    outputPath,
    entries: entries.map((entry) => entry.archivePath),
    sha256: createHash("sha256").update(archive).digest("hex"),
  };
}

async function main() {
  const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const packageJson = JSON.parse(
    await readFile(path.join(repositoryRoot, "package.json"), "utf8"),
  );
  const outputIndex = process.argv.indexOf("--output");
  const outputPath =
    outputIndex === -1
      ? path.join(
          repositoryRoot,
          "dist",
          `tg-agent-plugin-${packageJson.version}.tar.gz`,
        )
      : path.resolve(process.argv[outputIndex + 1]);
  if (!outputPath) throw new Error("--output requires a path");

  const result = await buildPackage(repositoryRoot, outputPath);
  process.stdout.write(
    `${result.outputPath}\nentries=${result.entries.length}\nsha256=${result.sha256}\n`,
  );
}

if (
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url
) {
  await main();
}
