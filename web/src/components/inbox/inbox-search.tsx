"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { useI18n } from "@/i18n/client";
import { relativeTime } from "@/lib/format";
import { searchMessages, threadHref, type SearchHit } from "@/lib/inbox";
import type { Profile } from "@/lib/queries";
import { createClient } from "@/lib/supabase/client";

/** ts_headline marks matches with << >>; render those as <mark>. */
function Highlighted({ text }: { text: string }) {
  const parts = text.split(/(<<[^>]*>>)/g);
  return (
    <>
      {parts.map((part, i) =>
        part.startsWith("<<") && part.endsWith(">>") ? (
          <mark key={i} className="rounded bg-amber-200 px-0.5">
            {part.slice(2, -2)}
          </mark>
        ) : (
          <span key={i}>{part}</span>
        )
      )}
    </>
  );
}

export function InboxSearch({
  projects,
  people,
}: {
  projects: { id: string; name: string }[];
  people: Pick<Profile, "id" | "full_name" | "role">[];
}) {
  const { t, locale } = useI18n();
  const [query, setQuery] = useState("");
  const [projectId, setProjectId] = useState("");
  const [senderId, setSenderId] = useState("");
  const [onlyPhotos, setOnlyPhotos] = useState(false);
  const [onlyVoice, setOnlyVoice] = useState(false);
  const [hits, setHits] = useState<SearchHit[] | null>(null);
  const [busy, setBusy] = useState(false);

  const hasFilter = Boolean(projectId || senderId || onlyPhotos || onlyVoice);
  const active = query.trim().length >= 2 || hasFilter;

  useEffect(() => {
    if (!active) {
      setHits(null);
      return;
    }
    let cancelled = false;
    setBusy(true);
    // Debounce: the RPC is cheap but not free, and every keystroke would queue.
    const timer = setTimeout(async () => {
      const rows = await searchMessages(createClient(), {
        query: query.trim() || undefined,
        projectIds: projectId ? [projectId] : undefined,
        senderIds: senderId ? [senderId] : undefined,
        hasPhoto: onlyPhotos ? true : undefined,
        hasVoice: onlyVoice ? true : undefined,
      });
      if (!cancelled) {
        setHits(rows);
        setBusy(false);
      }
    }, 250);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [query, projectId, senderId, onlyPhotos, onlyVoice, active]);

  const chip = (on: boolean) =>
    `rounded-full px-3 py-1.5 text-xs font-semibold transition-colors ${
      on
        ? "bg-slate-900 text-white"
        : "bg-white text-slate-600 ring-1 ring-slate-200 hover:bg-slate-50"
    }`;

  return (
    <div className="space-y-4">
      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder={t("inbox.search.placeholder")}
        className="w-full rounded-xl border border-slate-300 px-4 py-3 text-sm outline-none focus:border-slate-900"
      />

      <div className="flex flex-wrap items-center gap-2">
        <select
          value={projectId}
          onChange={(e) => setProjectId(e.target.value)}
          className="rounded-full border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-600"
        >
          <option value="">{t("inbox.person.allProjects")}</option>
          {projects.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>

        <select
          value={senderId}
          onChange={(e) => setSenderId(e.target.value)}
          className="rounded-full border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-600"
        >
          <option value="">{t("inbox.person.pick")}</option>
          {people.map((p) => (
            <option key={p.id} value={p.id}>
              {p.full_name}
            </option>
          ))}
        </select>

        <button type="button" className={chip(onlyPhotos)}
          onClick={() => setOnlyPhotos((v) => !v)}>
          {t("inbox.search.onlyPhotos")}
        </button>
        <button type="button" className={chip(onlyVoice)}
          onClick={() => setOnlyVoice((v) => !v)}>
          {t("inbox.search.onlyVoice")}
        </button>
      </div>

      {!active && (
        <p className="px-1 text-sm text-slate-500">{t("inbox.search.hint")}</p>
      )}
      {active && busy && (
        <p className="px-1 text-sm text-slate-500">{t("inbox.search.searching")}</p>
      )}
      {active && !busy && hits?.length === 0 && (
        <p className="px-1 text-sm text-slate-500">
          {t("inbox.search.noResults", { query: query.trim() })}
        </p>
      )}

      <ul className="space-y-1">
        {hits?.map((hit) => (
          <li key={hit.id}>
            <Link
              href={threadHref(hit)}
              className="block rounded-xl px-3 py-2.5 transition-colors hover:bg-slate-50"
            >
              <div className="flex items-baseline gap-2">
                <span className="truncate text-sm text-slate-700">
                  {hit.headline ? (
                    <Highlighted text={hit.headline} />
                  ) : (
                    hit.body ?? (hit.has_photo ? t("inbox.photo") : t("inbox.voice"))
                  )}
                </span>
                <span className="ml-auto shrink-0 text-xs text-slate-400">
                  {relativeTime(hit.created_at, locale)}
                </span>
              </div>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
