"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { Avatar } from "@/components/avatar";
import { RoleBadge } from "@/components/status-pill";
import { useI18n } from "@/i18n/client";
import { relativeTime } from "@/lib/format";
import { getPersonMessages, threadHref, type PersonMessage } from "@/lib/inbox";
import type { Profile } from "@/lib/queries";
import { createClient } from "@/lib/supabase/client";

/**
 * "What did I exchange with that person — and on which project?"
 * The project filter is the point: someone who works across four sites is
 * otherwise impossible to follow.
 */
export function PersonLens({
  people,
  projects,
}: {
  people: Pick<Profile, "id" | "full_name" | "role">[];
  projects: { id: string; name: string }[];
}) {
  const { t, locale } = useI18n();
  const [personId, setPersonId] = useState<string | null>(null);
  const [projectId, setProjectId] = useState("");
  const [rows, setRows] = useState<PersonMessage[] | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!personId) {
      setRows(null);
      return;
    }
    let cancelled = false;
    setBusy(true);
    (async () => {
      const data = await getPersonMessages(
        createClient(),
        personId,
        projectId || undefined
      );
      if (!cancelled) {
        setRows(data);
        setBusy(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [personId, projectId]);

  return (
    <div className="grid gap-4 md:grid-cols-[minmax(0,16rem)_1fr]">
      <aside className="space-y-1 rounded-2xl border border-slate-200 bg-white p-2">
        {people.length === 0 && (
          <p className="px-3 py-6 text-center text-sm text-slate-500">
            {t("inbox.person.noOthers")}
          </p>
        )}
        {people.map((p) => (
          <button
            key={p.id}
            type="button"
            onClick={() => setPersonId(p.id)}
            className={`flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors ${
              personId === p.id ? "bg-slate-900 text-white" : "hover:bg-slate-50"
            }`}
          >
            <Avatar name={p.full_name} />
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-semibold">
                {p.full_name}
              </span>
              {personId !== p.id && <RoleBadge role={p.role} />}
            </span>
          </button>
        ))}
      </aside>

      <div className="space-y-3">
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

        {!personId && (
          <p className="rounded-2xl border border-dashed border-slate-300 px-4 py-10 text-center text-sm text-slate-500">
            {t("inbox.person.pick")}
          </p>
        )}
        {personId && busy && (
          <p className="px-1 text-sm text-slate-500">{t("common.loading")}</p>
        )}
        {personId && !busy && rows?.length === 0 && (
          <p className="rounded-2xl border border-dashed border-slate-300 px-4 py-10 text-center text-sm text-slate-500">
            {t("inbox.person.empty")}
          </p>
        )}

        <ul className="space-y-1">
          {rows?.map((m) => (
            <li key={m.id}>
              <Link
                href={threadHref(m)}
                className="block rounded-xl border border-slate-200 bg-white px-3 py-2.5 transition-colors hover:bg-slate-50"
              >
                <div className="flex items-baseline gap-2">
                  <span
                    className={`shrink-0 rounded-full px-2 py-0.5 text-[11px] font-bold ${
                      m.direction === "from"
                        ? "bg-slate-100 text-slate-600"
                        : "bg-sky-100 text-sky-800"
                    }`}
                  >
                    {m.direction === "from"
                      ? t("inbox.person.from")
                      : t("inbox.person.to")}
                  </span>
                  <span className="truncate text-sm text-slate-700">
                    {m.body ??
                      (m.has_photo ? t("inbox.photo") : t("inbox.voice"))}
                  </span>
                  <span className="ml-auto shrink-0 text-xs text-slate-400">
                    {relativeTime(m.created_at, locale)}
                  </span>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
