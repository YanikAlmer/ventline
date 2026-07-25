"use client";

import Link from "next/link";

import { Avatar } from "@/components/avatar";
import { useI18n } from "@/i18n/client";
import { type InboxThread, threadHref } from "@/lib/inbox";
import { relativeTime } from "@/lib/format";
import { localizeSystemBody } from "@/lib/system-messages";

/** Media threads have no body, so the preview needs a stand-in. */
function preview(t: InboxThread, photo: string, voice: string): string | null {
  if (t.last_preview) return t.last_preview;
  if (t.last_kind === "photo") return photo;
  if (t.last_kind === "voice") return voice;
  return null;
}

export function ThreadRow({
  thread,
  nested = false,
}: {
  thread: InboxThread;
  nested?: boolean;
}) {
  const { t, locale } = useI18n();
  const unread = thread.unread_count ?? 0;
  const mentions = thread.unread_mention_count ?? 0;
  const raw = preview(thread, t("inbox.photo"), t("inbox.voice"));
  const body =
    thread.last_kind === "system" ? localizeSystemBody(raw, t) : raw;

  return (
    <Link
      href={threadHref(thread)}
      className={`flex items-start gap-3 rounded-xl px-3 py-3 transition-colors hover:bg-slate-50 ${
        nested ? "ml-4 border-l-2 border-slate-100 pl-4" : ""
      }`}
    >
      <Avatar name={thread.last_sender_name ?? "?"} />

      <div className="min-w-0 flex-1">
        <div className="flex items-baseline gap-2">
          <span
            className={`truncate text-sm ${
              unread > 0 ? "font-bold text-slate-900" : "font-semibold text-slate-700"
            }`}
          >
            {thread.task_title ?? t("inbox.projectThread")}
          </span>
          {thread.last_message_at && (
            <span className="ml-auto shrink-0 text-xs text-slate-400">
              {relativeTime(thread.last_message_at, locale)}
            </span>
          )}
        </div>

        <p
          className={`mt-0.5 truncate text-sm ${
            unread > 0 ? "text-slate-700" : "text-slate-500"
          }`}
        >
          {thread.last_sender_name && (
            <span className="font-medium">{thread.last_sender_name}: </span>
          )}
          {body ?? t("inbox.noMessages")}
        </p>
      </div>

      <div className="flex shrink-0 flex-col items-end gap-1">
        {mentions > 0 && (
          <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-bold text-amber-800">
            @{mentions}
          </span>
        )}
        {unread > 0 && (
          <span className="min-w-5 rounded-full bg-slate-900 px-1.5 py-0.5 text-center text-[11px] font-bold text-white">
            {unread}
          </span>
        )}
      </div>
    </Link>
  );
}
