"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";

import {
  LOCALES,
  LOCALE_COOKIE,
  LOCALE_COOKIE_MAX_AGE,
  LOCALE_LABELS,
  type Locale,
} from "@/i18n/config";
import { useI18n } from "@/i18n/client";

/**
 * Quiet language switch in the page footer. Writes the locale cookie and
 * re-renders: every server component re-reads the cookie, so the whole page
 * (including server-rendered copy) switches language.
 */
export function LanguageSwitch() {
  const { locale, t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function choose(next: Locale) {
    if (next === locale) return;
    document.cookie = `${LOCALE_COOKIE}=${next};path=/;max-age=${LOCALE_COOKIE_MAX_AGE};samesite=lax`;
    startTransition(() => router.refresh());
  }

  return (
    <div
      className="flex items-center justify-center gap-1 py-4 text-xs text-slate-400"
      data-pending={pending ? "" : undefined}
    >
      <span className="sr-only">{t("footer.language")}</span>
      {LOCALES.map((option, index) => (
        <span key={option} className="flex items-center gap-1">
          {index > 0 && <span aria-hidden>·</span>}
          <button
            type="button"
            onClick={() => choose(option)}
            aria-current={option === locale ? "true" : undefined}
            lang={option}
            className={
              option === locale
                ? "font-semibold text-slate-600 underline underline-offset-2"
                : "transition-colors hover:text-slate-600"
            }
          >
            {LOCALE_LABELS[option]}
          </button>
        </span>
      ))}
    </div>
  );
}
