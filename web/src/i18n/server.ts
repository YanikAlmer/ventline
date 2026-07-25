import "server-only";

import { cookies, headers } from "next/headers";

import {
  DEFAULT_LOCALE,
  LOCALE_COOKIE,
  isLocale,
  localeFromAcceptLanguage,
  type Locale,
} from "@/i18n/config";
import { createTranslator, type Translator } from "@/i18n/translate";

/**
 * Active locale for this request: an explicit choice from the language switch
 * wins, otherwise the browser's Accept-Language, otherwise German.
 */
export async function getLocale(): Promise<Locale> {
  const cookieStore = await cookies();
  const chosen = cookieStore.get(LOCALE_COOKIE)?.value;
  if (isLocale(chosen)) return chosen;

  try {
    const headerStore = await headers();
    return localeFromAcceptLanguage(headerStore.get("accept-language"));
  } catch {
    return DEFAULT_LOCALE;
  }
}

/** Server-side translator for the current request. */
export async function getTranslator(): Promise<Translator> {
  return createTranslator(await getLocale());
}
