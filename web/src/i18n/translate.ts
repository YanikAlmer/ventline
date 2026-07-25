import type { Locale } from "@/i18n/config";
import { de } from "@/i18n/dictionaries/de";
import { en, type TranslationKey } from "@/i18n/dictionaries/en";

export type { TranslationKey };

export type TranslationValues = Record<string, string | number>;

const DICTIONARIES: Record<Locale, Record<TranslationKey, string>> = { de, en };

export function getDictionary(locale: Locale): Record<TranslationKey, string> {
  return DICTIONARIES[locale];
}

/**
 * Look up a key and substitute {placeholders}.
 *
 * Pluralisation: pass `count` and define `<key>_one` / `<key>_other` entries;
 * the plain key is used when no count is given. German and English share the
 * same one/other split, so a rule table is unnecessary.
 */
export function translate(
  dict: Record<TranslationKey, string>,
  key: TranslationKey,
  values?: TranslationValues
): string {
  let lookupKey: string = key;

  if (values && typeof values.count === "number") {
    const plural = values.count === 1 ? `${key}_one` : `${key}_other`;
    if (plural in dict) lookupKey = plural;
  }

  const template = (dict as Record<string, string>)[lookupKey] ?? (dict as Record<string, string>)[key];

  if (template === undefined) {
    // Missing keys are a bug, not a crash: show the key so it is obvious in UI
    // and in tests, rather than rendering "undefined".
    if (process.env.NODE_ENV !== "production") {
      console.warn(`[i18n] missing translation for "${key}"`);
    }
    return key;
  }

  if (!values) return template;

  return template.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in values ? String(values[name]) : match
  );
}

export type Translator = (key: TranslationKey, values?: TranslationValues) => string;

export function createTranslator(locale: Locale): Translator {
  const dict = getDictionary(locale);
  return (key, values) => translate(dict, key, values);
}
