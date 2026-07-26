"use client";

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

  // Initial page.
  useEffect(() => {
    let cancelled = false;
    (async () => {
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
  }, [threadQuery]);

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
                <div key={message.id}>
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
