"use client";

export type DownscaledImage = {
  blob: Blob;
  width: number;
  height: number;
};

const MAX_DIMENSION = 2048;
const JPEG_QUALITY = 0.85;

/**
 * Downscale an image file client-side to at most 2048px on its longest edge
 * and re-encode as JPEG, so job-site photos upload fast on cell connections.
 */
export async function downscaleImage(file: File): Promise<DownscaledImage> {
  const bitmap = await createImageBitmap(file);
  try {
    const scale = Math.min(
      1,
      MAX_DIMENSION / Math.max(bitmap.width, bitmap.height)
    );
    const width = Math.max(1, Math.round(bitmap.width * scale));
    const height = Math.max(1, Math.round(bitmap.height * scale));

    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Canvas 2D context unavailable");
    ctx.drawImage(bitmap, 0, 0, width, height);

    const blob = await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob(
        (b) => (b ? resolve(b) : reject(new Error("JPEG encoding failed"))),
        "image/jpeg",
        JPEG_QUALITY
      );
    });

    return { blob, width, height };
  } finally {
    bitmap.close();
  }
}

/** Swap the original extension for .jpg after re-encoding. */
export function jpegFilename(originalName: string): string {
  const base = originalName.replace(/\.[^.]+$/, "") || "photo";
  return `${base}.jpg`;
}
