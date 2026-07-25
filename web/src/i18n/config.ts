/**
 * Locale configuration.
 *
 * German is the default: it is what an unrecognised Accept-Language falls back
 * to, matching the iOS app (CFBundleDevelopmentRegion = de).
 */

export const LOCALES = ["de", "en"] as const;

export type Locale = (typeof LOCALES)[number];

export const DEFAULT_LOCALE: Locale = "de";

/** Cookie the language switch writes; read on every server render. */
export const LOCALE_COOKIE = "ventline_locale";

/** One year — the choice should survive sessions. */
export const LOCALE_COOKIE_MAX_AGE = 60 * 60 * 24 * 365;

export const LOCALE_LABELS: Record<Locale, string> = {
  de: "Deutsch",
  en: "English",
};

export function isLocale(value: unknown): value is Locale {
  return typeof value === "string" && (LOCALES as readonly string[]).includes(value);
}

/**
 * Pick the best locale from an Accept-Language header, honouring q-values.
 * Falls back to German when nothing matches.
 */
export function localeFromAcceptLanguage(header: string | null): Locale {
  if (!header) return DEFAULT_LOCALE;

  const ranked = header
    .split(",")
    .map((part) => {
      const [tag, ...params] = part.trim().split(";");
      const q = params
        .map((p) => p.trim())
        .find((p) => p.startsWith("q="))
        ?.slice(2);
      const quality = q === undefined ? 1 : Number.parseFloat(q);
      return {
        // "de-CH" and "de" both select German.
        base: tag.trim().toLowerCase().split("-")[0],
        quality: Number.isFinite(quality) ? quality : 0,
      };
    })
    .filter((entry) => entry.quality > 0)
    .sort((a, b) => b.quality - a.quality);

  for (const entry of ranked) {
    if (isLocale(entry.base)) return entry.base;
  }
  return DEFAULT_LOCALE;
}
