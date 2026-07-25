"use client";

import Link from "next/link";
import { useState } from "react";

import { ThreadRow } from "@/components/inbox/thread-row";
import { InboxSearch } from "@/components/inbox/inbox-search";
import { PersonLens } from "@/components/inbox/person-lens";
import { useI18n } from "@/i18n/client";
import { relativeTime } from "@/lib/format";
import {
  groupByProject,
  threadHref,
  type AttentionItem,
  type InboxThread,
} from "@/lib/inbox";
import type { Profile } from "@/lib/queries";

type Pivot = "project" | "person" | "search";

export function InboxView({
  threads,
  attention,
  people,
  projects,
  currentUserId,
}: {
  threads: InboxThread[];
  attention: AttentionItem[];
  people: Pick<Profile, "id" | "full_name" | "role">[];
  projects: { id: string; name: string }[];
  currentUserId: string;
}) {
  const { t, locale } = useI18n();
  const [pivot, setPivot] = useState<Pivot>("project");
  const groups = groupByProject(threads);

  const pivotClass = (active: boolean) =>
    `rounded-full px-4 py-2 text-sm font-semibold transition-colors ${
      active
        ? "bg-slate-900 text-white"
        : "bg-white text-slate-600 ring-1 ring-slate-200 hover:bg-slate-50"
    }`;

  return (
    <div className="space-y-6">
      {/* Attention first: the whole point of the screen is not having to hunt. */}
      {attention.length > 0 && (
        <section className="rounded-2xl border border-amber-200 bg-amber-50/60 p-4">
          <h2 className="mb-2 text-xs font-bold uppercase tracking-wide text-amber-800">
            {t("inbox.attention.title")}
          </h2>
          <ul className="space-y-1">
            {attention.map((item) => (
              <li key={`${item.reason}-${item.message_id}`}>
                <Link
                  href={threadHref(item)}
                  className="flex items-center gap-2 rounded-lg px-2 py-2 text-sm hover:bg-amber-100/60"
                >
                  <span className="shrink-0 rounded-full bg-amber-200 px-2 py-0.5 text-[11px] font-bold text-amber-900">
                    {item.reason === "mention"
                      ? t("inbox.attention.mention")
                      : t("inbox.attention.myTask")}
                  </span>
                  <span className="truncate text-slate-700">
                    {item.body ?? t("inbox.photo")}
                  </span>
                  <span className="ml-auto shrink-0 text-xs text-amber-700">
                    {relativeTime(item.created_at, locale)}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}

      <div className="flex flex-wrap gap-2">
        <button type="button" className={pivotClass(pivot === "project")}
          onClick={() => setPivot("project")}>
          {t("inbox.pivot.project")}
        </button>
        <button type="button" className={pivotClass(pivot === "person")}
          onClick={() => setPivot("person")}>
          {t("inbox.pivot.person")}
        </button>
        <button type="button" className={pivotClass(pivot === "search")}
          onClick={() => setPivot("search")}>
          {t("inbox.pivot.search")}
        </button>
      </div>

      {pivot === "project" && (
        <div className="space-y-4">
          {groups.length === 0 && (
            <p className="rounded-2xl border border-dashed border-slate-300 px-4 py-10 text-center text-sm text-slate-500">
              {t("inbox.empty")}
            </p>
          )}

          {groups.map((g) => (
            <section
              key={g.projectId}
              className="overflow-hidden rounded-2xl border border-slate-200 bg-white"
            >
              <header className="flex items-center gap-2 border-b border-slate-100 px-4 py-3">
                <Link
                  href={`/projects/${g.projectId}`}
                  className="truncate text-sm font-bold text-slate-900 hover:underline"
                >
                  {g.projectName}
                </Link>
                {g.mentionCount > 0 && (
                  <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-bold text-amber-800">
                    @{g.mentionCount}
                  </span>
                )}
                {g.unreadCount > 0 && (
                  <span className="rounded-full bg-slate-900 px-2 py-0.5 text-[11px] font-bold text-white">
                    {t("inbox.unread", { count: g.unreadCount })}
                  </span>
                )}
              </header>

              <div className="p-1">
                {g.projectThread && <ThreadRow thread={g.projectThread} />}
                {g.taskThreads.map((th) => (
                  <ThreadRow key={th.thread_id} thread={th} nested />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}

      {pivot === "person" && (
        <PersonLens
          people={people.filter((p) => p.id !== currentUserId)}
          projects={projects}
        />
      )}

      {pivot === "search" && <InboxSearch projects={projects} people={people} />}
    </div>
  );
}
