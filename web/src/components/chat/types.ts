import type { Tables } from "@/lib/database.types";

export type ChatSender = Pick<
  Tables<"profiles">,
  "id" | "full_name" | "role"
>;

export type ChatAnnotation = Pick<
  Tables<"photo_annotations">,
  "id" | "rendered_path" | "created_at"
>;

export type ChatAttachment = Tables<"attachments"> & {
  photo_annotations: ChatAnnotation[];
};

export type ChatMessage = Tables<"messages"> & {
  sender: ChatSender | null;
  attachments: ChatAttachment[];
};

export const MESSAGE_SELECT =
  "*, sender:profiles!messages_sender_id_fkey(id, full_name, role), attachments(*, photo_annotations(id, rendered_path, created_at))";

export const PAGE_SIZE = 50;

/**
 * Display path for a photo attachment: the newest annotation's flattened
 * render when one exists, otherwise the raw photo.
 */
export function displayPhoto(attachment: ChatAttachment): {
  path: string;
  annotated: boolean;
} {
  const newest = [...attachment.photo_annotations].sort((a, b) =>
    b.created_at.localeCompare(a.created_at)
  )[0];
  if (newest) return { path: newest.rendered_path, annotated: true };
  return { path: attachment.storage_path, annotated: false };
}

/** Normalized waveform bars from the jsonb column (0..1 floats). */
export function waveformBars(waveform: Tables<"attachments">["waveform"]): number[] {
  if (!Array.isArray(waveform)) return [];
  return waveform
    .filter((v): v is number => typeof v === "number")
    .map((v) => Math.min(1, Math.max(0, v)));
}
