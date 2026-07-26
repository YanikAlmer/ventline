"use client";

import { useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { RealtimePostgresInsertPayload } from "@supabase/supabase-js";

import { useI18n } from "@/i18n/client";
import type { Tables } from "@/lib/database.types";
import { dayHeading, dayKey } from "@/lib/format";
import { isOffice, type AppRole } from "@/lib/status";
import { SIGNED_URL_TTL_SECONDS } from "@/lib/storage";
import { createClient } from "@/lib/supabase/client";

import { Composer } from "./composer";
import { Lightbox } from "./lightbox";
import { MessageBubble } from "./message-bubble";
import {
  displayPhoto,
  MESSAGE_SELECT,
  PAGE_SIZE,
  type ChatMessage,
} from "./types";

type LightboxState = { url: string; caption: string | null } | null;

export function ChatThread({
  companyId,
  projectId,
  taskId,
  currentUserId,
  role,
}: {
  companyId: string;
  projectId: string;
  taskId: string | null;
  currentUserId: string;
  role: AppRole;
}) {
  const { t, locale } = useI18n();
  const supabase = useMemo(() => createClient(), []);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [urls, setUrls] = useState<Map<string, string>>(new Map());
  const [lightbox, setLightbox] = useState<LightboxState>(null);
  const bottomRef = useRef<HTMLDivElement>(null);
  const signedPathsRef = useRef<Set<string>>(new Set());

  /**
   * A search hit links here with ?m=<id>. Landing at the bottom of a
   * 400-message thread is not "finding" anything — what makes a hit useful is
   * the conversation around it, so the thread opens on a window centred there
   * instead of on the newest page.
   */
  const focusMessageId = useSearchParams().get("m");

  const threadQuery = useCallback(() => {
    let query = supabase
      .from("messages")
      .select(MESSAGE_SELECT)
      .eq("project_id", projectId)
      .order("created_at", { ascending: false })
      .limit(PAGE_SIZE);
    query = taskId ? query.eq("task_id", taskId) : query.is("task_id", null);
    return query;
  }, [supabase, projectId, taskId]);

  const appendMessage = useCallback((message: ChatMessage) => {
    setMessages((prev) => {
      if (prev.some((m) => m.id === message.id)) return prev;
      return [...prev, message].sort((a, b) =>
        a.created_at.localeCompare(b.created_at)
      );
    });
  }, []);

  const fetchOne = useCallback(
    async (messageId: string): Promise<ChatMessage | null> => {
      const { data } = await supabase
        .from("messages")
        .select(MESSAGE_SELECT)
        .eq("id", messageId)
        .maybeSingle();
      return (data as unknown as ChatMessage | null) ?? null;
    },
    [supabase]
  );

  // Initial page — or a window around the message a search hit pointed at.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (focusMessageId) {
        const { data: around } = await supabase.rpc("messages_around", {
          p_message_id: focusMessageId,
        });
        const ids = (around ?? []).map((m) => m.id);
        if (ids.length > 0) {
          // Re-queried with MESSAGE_SELECT: messages_around returns bare rows,
          // and a bubble needs its sender, attachments and annotations too.
          const { data } = await supabase
            .from("messages")
            .select(MESSAGE_SELECT)
            .in("id", ids)
            .order("created_at", { ascending: true });
          if (cancelled) return;
          setMessages((data as unknown as ChatMessage[] | null) ?? []);
          // Older messages certainly exist above a window; the button is
          // cheap and the alternative is a thread that looks truncated.
          setHasMore(true);
          setLoading(false);
          requestAnimationFrame(() => {
            document
              .querySelector(`[data-message-id="${focusMessageId}"]`)
              ?.scrollIntoView({ block: "center" });
          });
          return;
        }
        // The message was deleted, expired, or is not visible to this reader.
        // Falling through to the newest page beats an empty thread.
      }

      const { data } = await threadQuery();
      if (cancelled) return;
      const page = ((data as unknown as ChatMessage[] | null) ?? []).reverse();
      setMessages(page);
      setHasMore(page.length === PAGE_SIZE);
      setLoading(false);
      requestAnimationFrame(() =>
        bottomRef.current?.scrollIntoView({ block: "end" })
      );
    })();
    return () => {
      cancelled = true;
    };
  }, [threadQuery, focusMessageId, supabase]);

  /**
   * Clear the unread badge, and acknowledge any mentions in the thread.
   *
   * On open and again on leave: opening covers what was already there, leaving
   * covers whatever arrived while it was on screen. markThreadRead has existed
   * since the read-model migration and nothing called it on either client, so
   * an unread count — and an unacknowledged mention, which is what feeds the
   * attention list — could never clear.
   */
  useEffect(() => {
    const threadId = taskId ?? projectId;
    void supabase.rpc("mark_thread_read", { p_thread_id: threadId });
    return () => {
      void supabase.rpc("mark_thread_read", { p_thread_id: threadId });
    };
  }, [supabase, projectId, taskId]);

  // Realtime inserts.
  useEffect(() => {
    const filter = taskId
      ? `task_id=eq.${taskId}`
      : `project_id=eq.${projectId}`;
    const channel = supabase
      .channel(`thread-${taskId ?? projectId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "messages", filter },
        async (payload: RealtimePostgresInsertPayload<Tables<"messages">>) => {
          const row = payload.new;
          // Project-level thread: skip task-thread messages (the filter is
          // project-wide because realtime filters cannot express "is null").
          if (!taskId && row.task_id !== null) return;
          const full = await fetchOne(row.id);
          if (full) {
            appendMessage(full);
            requestAnimationFrame(() =>
              bottomRef.current?.scrollIntoView({ behavior: "smooth" })
            );
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [supabase, projectId, taskId, fetchOne, appendMessage]);

  // Sign storage URLs for any attachment paths we have not signed yet.
  useEffect(() => {
    const wanted = new Map<string, Set<string>>(); // bucket -> paths
    for (const message of messages) {
      for (const att of message.attachments) {
        const entries: [string, string][] =
          att.kind === "photo"
            ? [["photos", displayPhoto(att).path]]
            : [[att.storage_bucket, att.storage_path]];
        for (const [bucket, path] of entries) {
          if (signedPathsRef.current.has(path)) continue;
          if (!wanted.has(bucket)) wanted.set(bucket, new Set());
          wanted.get(bucket)!.add(path);
        }
      }
    }
    if (wanted.size === 0) return;

    (async () => {
      const additions = new Map<string, string>();
      for (const [bucket, paths] of wanted) {
        const list = [...paths];
        list.forEach((p) => signedPathsRef.current.add(p));
        const { data } = await supabase.storage
          .from(bucket)
          .createSignedUrls(list, SIGNED_URL_TTL_SECONDS);
        for (const entry of data ?? []) {
          if (entry.path && entry.signedUrl) {
            additions.set(entry.path, entry.signedUrl);
          }
        }
      }
      if (additions.size > 0) {
        setUrls((prev) => new Map([...prev, ...additions]));
      }
    })();
  }, [messages, supabase]);

  async function loadOlder() {
    if (messages.length === 0) return;
    setLoadingOlder(true);
    const oldest = messages[0].created_at;
    const { data } = await threadQuery().lt("created_at", oldest);
    const page = ((data as unknown as ChatMessage[] | null) ?? []).reverse();
    setMessages((prev) => {
      const known = new Set(prev.map((m) => m.id));
      return [...page.filter((m) => !known.has(m.id)), ...prev];
    });
    setHasMore(page.length === PAGE_SIZE);
    setLoadingOlder(false);
  }

  async function handleDelete(messageId: string) {
    const { error } = await supabase.rpc("delete_message", {
      p_message_id: messageId,
    });
    if (error) {
      alert(t("chat.deleteFailed", { message: error.message }));
      return;
    }
    setMessages((prev) => prev.filter((m) => m.id !== messageId));
  }

  async function handleSent(messageId: string) {
    const full = await fetchOne(messageId);
    if (full) {
      appendMessage(full);
      requestAnimationFrame(() =>
        bottomRef.current?.scrollIntoView({ behavior: "smooth" })
      );
    }
  }

  // Group consecutive messages by day for headings.
  const withHeadings: { heading: string | null; message: ChatMessage }[] = [];
  let lastDay = "";
  for (const message of messages) {
    const key = dayKey(message.created_at);
    withHeadings.push({
      heading: key !== lastDay ? dayHeading(message.created_at, locale) : null,
      message,
    });
    lastDay = key;
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-2xl border border-slate-200 bg-slate-50 shadow-sm">
      <div className="min-h-0 flex-1 overflow-y-auto p-4">
        {loading ? (
          <p className="py-8 text-center text-sm text-slate-400">
            {t("chat.loadingMessages")}
          </p>
        ) : (
          <>
            {hasMore && (
              <div className="mb-4 text-center">
                <button
                  type="button"
                  onClick={loadOlder}
                  disabled={loadingOlder}
                  className="rounded-full border border-slate-300 bg-white px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50 disabled:opacity-50"
                >
                  {loadingOlder ? t("common.loading") : t("chat.loadOlder")}
                </button>
              </div>
            )}
            {messages.length === 0 && (
              <p className="py-8 text-center text-sm text-slate-400">
                {t("chat.empty")}
              </p>
            )}
            <div className="space-y-2.5">
              {withHeadings.map(({ heading, message }) => (
                <div
                  key={message.id}
                  data-message-id={message.id}
                  // The hit itself is marked, or you arrive in the middle of a
                  // conversation with no idea which line you were looking for.
                  className={
                    message.id === focusMessageId
                      ? "rounded-xl bg-amber-50 ring-2 ring-amber-300"
                      : undefined
                  }
                >
                  {heading && (
                    <div className="my-4 text-center text-xs font-bold uppercase tracking-wide text-slate-400">
                      {heading}
                    </div>
                  )}
                  <MessageBubble
                    message={message}
                    own={message.sender_id === currentUserId}
                    currentProfileId={currentUserId}
                    canDelete={
                      message.kind !== "system" &&
                      (message.sender_id === currentUserId || isOffice(role))
                    }
                    urls={urls}
                    onOpenPhoto={(url, caption) =>
                      setLightbox({ url, caption })
                    }
                    onDelete={handleDelete}
                  />
                </div>
              ))}
            </div>
            <div ref={bottomRef} />
          </>
        )}
      </div>

      <Composer
        companyId={companyId}
        projectId={projectId}
        taskId={taskId}
        onSent={handleSent}
      />

      {lightbox && (
        <Lightbox
          url={lightbox.url}
          caption={lightbox.caption}
          onClose={() => setLightbox(null)}
        />
      )}
    </div>
  );
}
