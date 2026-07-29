import Link from "next/link";

import { BrandMark } from "@/components/brand-mark";
import {
  OPERATOR,
  isConfigured,
  type Policy,
} from "@/content/privacy";

/**
 * Renders a policy. Long-form legal text lives in `content/privacy.ts` rather
 * than in the i18n dictionary: the dictionary is a flat map of short UI
 * strings, and paragraphs of legal prose in it would be unreadable to write
 * and impossible to review as a document.
 *
 * `**bold**` is the only markup supported, because it is the only one the text
 * needs and a Markdown dependency for one emphasis rule is not a trade worth
 * making.
 */
function emphasise(text: string, key: string) {
  return text.split(/(\*\*[^*]+\*\*)/g).map((part, index) =>
    part.startsWith("**") && part.endsWith("**") ? (
      <strong key={`${key}-${index}`} className="font-semibold text-slate-900">
        {part.slice(2, -2)}
      </strong>
    ) : (
      <span key={`${key}-${index}`}>{part}</span>
    ),
  );
}

export function PolicyPage({ policy }: { policy: Policy }) {
  return (
    <main className="mx-auto max-w-2xl px-5 py-10">
      <Link href="/" className="mb-8 flex items-center gap-2.5">
        <span className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-slate-900 p-1.5">
          <BrandMark className="size-full text-white" />
        </span>
        <span className="text-sm font-black text-slate-900">Ventline</span>
      </Link>

      {/* A published policy naming TODO_LEGAL_ENTITY as the controller is
          worse than no policy, so an unfilled placeholder is loud rather than
          quiet. This banner is the reason the values are obvious markers and
          not plausible-looking guesses. */}
      {!isConfigured && (
        <p className="mb-6 rounded-xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900">
          <strong className="font-semibold">Not ready to publish.</strong>{" "}
          Placeholders in <code>web/src/content/privacy.ts</code> still need the
          operator&rsquo;s legal entity, address, contact address, hosting region
          and date.
        </p>
      )}

      <h1 className="text-3xl font-black tracking-tight text-slate-900">
        {policy.title}
      </h1>
      <p className="mt-1 text-xs text-slate-500">
        {policy.lastUpdatedLabel}: {OPERATOR.lastUpdated}
      </p>

      {policy.intro.map((paragraph, index) => (
        <p key={index} className="mt-4 text-sm leading-relaxed text-slate-700">
          {emphasise(paragraph, `intro-${index}`)}
        </p>
      ))}

      {policy.sections.map((section) => (
        <section key={section.heading} className="mt-8">
          <h2 className="text-base font-bold text-slate-900">
            {section.heading}
          </h2>
          {section.body.map((paragraph, index) => (
            <p
              key={index}
              className="mt-2.5 text-sm leading-relaxed text-slate-700"
            >
              {emphasise(paragraph, `${section.heading}-${index}`)}
            </p>
          ))}
        </section>
      ))}

      <p className="mt-10 border-t border-slate-200 pt-5 text-sm">
        <Link
          href={policy.otherLanguage.href}
          className="font-semibold text-slate-900 underline"
        >
          {policy.otherLanguage.label}
        </Link>
      </p>
    </main>
  );
}
