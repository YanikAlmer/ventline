import { DEFAULT_LOCALE, type Locale } from "@/i18n/config";
import { createTranslator, type Translator } from "@/i18n/translate";

/**
 * Callers may pass either the active `Locale` (preferred — it also drives the
 * Intl date/time formats) or a `Translator` they already have to hand. Both
 * are optional so existing call sites keep working; without one, the app's
 * default locale (German) is used.
 */
export type FormatLocale = Locale | Translator;

type FormatContext = {
  t: Translator;
  /** Passed to Intl; `undefined` means "use the runtime default". */
  intl: string | undefined;
};

function context(input: FormatLocale = DEFAULT_LOCALE): FormatContext {
  if (typeof input === "function") {
    // Only a translator: keep the previous Intl behaviour (runtime default).
    return { t: input, intl: undefined };
  }
  return { t: createTranslator(input), intl: input };
}

/** Human-friendly relative time, e.g. "3h ago", "just now", "2d ago". */
export function relativeTime(
  iso: string | null | undefined,
  locale?: FormatLocale
): string {
  if (!iso) return "—";
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return "—";
  const seconds = Math.round((Date.now() - then) / 1000);
  const { t, intl } = context(locale);

  if (seconds < 45) return t("format.justNow");
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return t("format.minutesAgo", { count: minutes });
  const hours = Math.round(minutes / 60);
  if (hours < 24) return t("format.hoursAgo", { count: hours });
  const days = Math.round(hours / 24);
  if (days < 7) return t("format.daysAgo", { count: days });
  const weeks = Math.round(days / 7);
  if (weeks < 5) return t("format.weeksAgo", { count: weeks });
  return new Date(iso).toLocaleDateString(intl, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

/** "14:32" style clock time for chat bubbles. */
export function clockTime(iso: string, locale?: FormatLocale): string {
  return new Date(iso).toLocaleTimeString(context(locale).intl, {
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** "Monday, June 3" style day heading. */
export function dayHeading(iso: string, locale?: FormatLocale): string {
  const date = new Date(iso);
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const { t, intl } = context(locale);
  if (date.toDateString() === today.toDateString()) return t("format.today");
  if (date.toDateString() === yesterday.toDateString()) {
    return t("format.yesterday");
  }
  return date.toLocaleDateString(intl, {
    weekday: "long",
    month: "long",
    day: "numeric",
    year:
      date.getFullYear() === today.getFullYear() ? undefined : "numeric",
  });
}

/** Local calendar day key (YYYY-MM-DD) for grouping. */
export function dayKey(iso: string): string {
  const d = new Date(iso);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/** "Jun 3, 2026" for due dates (input is a date-only string). */
export function formatDate(
  dateOnly: string | null | undefined,
  locale?: FormatLocale
): string {
  if (!dateOnly) return "—";
  const d = new Date(`${dateOnly}T00:00:00`);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString(context(locale).intl, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

/** Initials for avatar circles: "Wanda Worker" -> "WW". */
export function initials(name: string | null | undefined): string {
  if (!name) return "?";
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}

/** Format audio duration: 83.4 -> "1:23". */
export function formatDuration(seconds: number | null | undefined): string {
  if (seconds == null || !Number.isFinite(seconds)) return "0:00";
  const total = Math.round(seconds);
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}
