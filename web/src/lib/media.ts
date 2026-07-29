/**
 * Video limits, mirrored client-side.
 *
 * The authority is the Storage bucket — `allowed_mime_types` and
 * `file_size_limit` on the `video` bucket — which rejects anything outside
 * these regardless of what any client believes. These exist so a 300 MB clip
 * fails in the picker rather than after the person has watched an upload bar
 * crawl across the screen on a jobsite connection.
 *
 * Shared rather than declared per component: the composer and the task-files
 * panel upload to the same bucket, and two copies of a limit is two things to
 * forget when the bucket changes.
 */
export const VIDEO_TYPES = ["video/mp4", "video/quicktime"] as const;

export const MAX_VIDEO_BYTES = 200 * 1024 * 1024;

export function isVideoFile(file: File): boolean {
  return file.type.startsWith("video/");
}

/**
 * Why this file cannot be sent, or null if it can. Returns a translation key
 * rather than a message so callers keep their own translator — typed as the
 * literal keys so a typo is a compile error rather than a blank message.
 */
export function videoRejectionKey(
  file: File
): "tasks.files.videoType" | "tasks.files.videoTooLarge" | null {
  if (!(VIDEO_TYPES as readonly string[]).includes(file.type)) {
    return "tasks.files.videoType";
  }
  if (file.size > MAX_VIDEO_BYTES) return "tasks.files.videoTooLarge";
  return null;
}
