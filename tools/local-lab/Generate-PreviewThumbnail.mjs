import { mkdir, rename, rm, stat } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import process from "node:process";
import sharp from "sharp";

const [, , inputArgument, outputArgument, widthArgument = "1280", heightArgument = "960"] = process.argv;

if (!inputArgument || !outputArgument) {
  console.error("Usage: node Generate-PreviewThumbnail.mjs <input> <output> [width] [height]");
  process.exit(2);
}

const inputPath = resolve(inputArgument);
const outputPath = resolve(outputArgument);
const maxWidth = Number.parseInt(widthArgument, 10);
const maxHeight = Number.parseInt(heightArgument, 10);
const temporaryPath = `${outputPath}.${process.pid}.${Date.now()}.tmp.jpg`;

if (!Number.isInteger(maxWidth) || !Number.isInteger(maxHeight) || maxWidth < 64 || maxHeight < 64) {
  console.error("Thumbnail dimensions must be integers of at least 64 pixels.");
  process.exit(2);
}

try {
  await mkdir(dirname(outputPath), { recursive: true });
  const result = await sharp(inputPath, {
    failOn: "error",
    limitInputPixels: false,
    sequentialRead: true,
  })
    .rotate()
    .resize({
      width: maxWidth,
      height: maxHeight,
      fit: "inside",
      withoutEnlargement: true,
      fastShrinkOnLoad: true,
    })
    .flatten({ background: "#f4f4f5" })
    .jpeg({ quality: 80, progressive: true, chromaSubsampling: "4:2:0" })
    .toFile(temporaryPath);

  await rm(outputPath, { force: true });
  await rename(temporaryPath, outputPath);
  const output = await stat(outputPath);
  process.stdout.write(JSON.stringify({
    width: result.width,
    height: result.height,
    bytes: output.size,
    format: "JPG",
  }));
} catch (error) {
  await rm(temporaryPath, { force: true }).catch(() => {});
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
