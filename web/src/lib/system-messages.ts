import type { TranslationKey, Translator } from "@/i18n/translate";

/**
 * System events are stored in the database in English so the row means the same
 * thing to every reader regardless of who triggered it. Translate at display
 * time instead — anywhere a system body is rendered, including thread previews,
 * not just the message bubble.
 */
const SYSTEM_BODY_KEYS: Record<string, TranslationKey> = {
  "started work": "chat.system.startedWork",
  "marked the task as done": "chat.system.markedDone",
  "flagged the task as blocked": "chat.system.flaggedBlocked",
  "approved the task": "chat.system.approved",
  "reopened the task": "chat.system.reopened",
};

/**
 * An unrecognised body (written by an older or newer client) falls back to the
 * stored text rather than disappearing.
 */
export function localizeSystemBody(
  body: string | null | undefined,
  t: Translator
): string | null {
  if (!body) return null;
  const key = SYSTEM_BODY_KEYS[body];
  return key ? t(key) : body;
}
