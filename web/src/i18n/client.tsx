"use client";

import { createContext, useContext, useMemo } from "react";

import type { Locale } from "@/i18n/config";
import { createTranslator, type Translator } from "@/i18n/translate";

type I18nContextValue = {
  locale: Locale;
  t: Translator;
};

const I18nContext = createContext<I18nContextValue | null>(null);

/**
 * Provides the request's locale to client components. The dictionaries are
 * plain modules, so nothing is serialised across the server/client boundary —
 * only the locale string is.
 */
export function I18nProvider({
  locale,
  children,
}: {
  locale: Locale;
  children: React.ReactNode;
}) {
  const value = useMemo<I18nContextValue>(
    () => ({ locale, t: createTranslator(locale) }),
    [locale]
  );
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nContextValue {
  const ctx = useContext(I18nContext);
  if (!ctx) {
    throw new Error("useI18n must be used inside <I18nProvider>");
  }
  return ctx;
}

/** Convenience: the translator on its own. */
export function useTranslator(): Translator {
  return useI18n().t;
}
