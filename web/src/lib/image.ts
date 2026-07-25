"use client";

import { DEFAULT_LOCALE } from "@/i18n/config";
import { createTranslator, type Translator } from "@/i18n/translate";

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
 *
 * The thrown error messages are shown to the user, so callers should pass the
 * translator from `useTranslator()`; without one the app's default locale
 * (German) is used.
 */
export async function downscaleImage(
  file: File,
  t: Translator = createTranslator(DEFAULT_LOCALE)
): Promise<DownscaledImage> {
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    // Desktop Chrome/Firefox cannot decode HEIC/HEIF (the default iPhone
    // format), so createImageBitmap rejects. Give the user an actionable
    // message instead of a raw DOMException.
    const isHeic =
      /hei[cf]/i.test(file.type) || /\.hei[cf]$/i.test(file.name);
    throw new Error(
      isHeic ? t("shared.image.heic") : t("shared.image.failed")
    );
  }
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
