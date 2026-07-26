import type { SupabaseClient } from "@supabase/supabase-js";

import type { Database } from "@/lib/database.types";
import type { ServerClient } from "@/lib/supabase/server";

/** Either client works: every RPC here is SECURITY INVOKER and RLS-filtered. */
type AnyClient = ServerClient | SupabaseClient<Database>;

export type InboxThread =
  Database["public"]["Functions"]["inbox_page"]["Returns"][number];

export type AttentionItem =
  Database["public"]["Functions"]["inbox_attention"]["Returns"][number];

export type SearchHit =
  Database["public"]["Functions"]["search_messages"]["Returns"][number];

export type PersonMessage =
  Database["public"]["Functions"]["person_messages"]["Returns"][number];

export async function getInboxThreads(
  supabase: AnyClient,
  projectId?: string
): Promise<InboxThread[]> {
  const { data } = await supabase.rpc("inbox_page", {
    p_project_id: projectId ?? undefined,
  });
  return data ?? [];
}

export async function getAttention(
  supabase: AnyClient
): Promise<AttentionItem[]> {
  const { data } = await supabase.rpc("inbox_attention", {});
  return data ?? [];
}

export type SearchFilters = {
  query?: string;
  projectIds?: string[];
  senderIds?: string[];
  hasPhoto?: boolean;
  hasVoice?: boolean;
};

export async function searchMessages(
  supabase: AnyClient,
  filters: SearchFilters
): Promise<SearchHit[]> {
  const { data } = await supabase.rpc("search_messages", {
    p_query: filters.query || undefined,
    p_project_ids: filters.projectIds?.length ? filters.projectIds : undefined,
    p_sender_ids: filters.senderIds?.length ? filters.senderIds : undefined,
    p_has_photo: filters.hasPhoto ?? undefined,
    p_has_voice: filters.hasVoice ?? undefined,
  });
  return data ?? [];
}

export async function getPersonMessages(
  supabase: AnyClient,
  profileId: string,
  projectId?: string
): Promise<PersonMessage[]> {
  const { data } = await supabase.rpc("person_messages", {
    p_profile_id: profileId,
    p_project_id: projectId ?? undefined,
  });
  return data ?? [];
}

/** Clears the unread badge and acknowledges any mentions in the thread. */
export async function markThreadRead(
  supabase: AnyClient,
  threadId: string
): Promise<void> {
  await supabase.rpc("mark_thread_read", { p_thread_id: threadId });
}

/**
 * Threads grouped by project, projects ordered by their most recent activity.
 * A flat list is unusable once a crew works across several sites — this is the
 * shape the overview actually renders.
 */
export type ProjectGroup = {
  projectId: string;
  projectName: string;
  projectThread: InboxThread | null;
  taskThreads: InboxThread[];
  unreadCount: number;
  mentionCount: number;
  lastMessageAt: string | null;
};

export function groupByProject(threads: InboxThread[]): ProjectGroup[] {
  const groups = new Map<string, ProjectGroup>();

  for (const t of threads) {
    let g = groups.get(t.project_id);
    if (!g) {
      g = {
        projectId: t.project_id,
        projectName: t.project_name,
        projectThread: null,
        taskThreads: [],
        unreadCount: 0,
        mentionCount: 0,
        lastMessageAt: null,
      };
      groups.set(t.project_id, g);
    }
    if (t.task_id) g.taskThreads.push(t);
    else g.projectThread = t;

    g.unreadCount += t.unread_count ?? 0;
    g.mentionCount += t.unread_mention_count ?? 0;
    if (
      t.last_message_at &&
      (!g.lastMessageAt || t.last_message_at > g.lastMessageAt)
    ) {
      g.lastMessageAt = t.last_message_at;
    }
  }

  const ordered = [...groups.values()];
  for (const g of ordered) {
    g.taskThreads.sort((a, b) =>
      (b.last_message_at ?? "").localeCompare(a.last_message_at ?? "")
    );
  }
  ordered.sort((a, b) =>
    (b.lastMessageAt ?? "").localeCompare(a.lastMessageAt ?? "")
  );
  return ordered;
}

/** Where a thread lives, so a row can link straight to the conversation. */
/**
 * Link to a thread, optionally anchored at one message.
 *
 * A search hit that dumps you at the bottom of a 400-message thread has not
 * really found anything — the point of a hit is the conversation around it. The
 * `m` parameter is read by the thread, which loads a window around that message
 * instead of the newest page.
 */
export function threadHref(
  t: { project_id: string; task_id: string | null; id?: string },
  focusMessageId?: string
): string {
  const base = t.task_id
    ? `/projects/${t.project_id}/tasks/${t.task_id}`
    : `/projects/${t.project_id}/chat`;
  const focus = focusMessageId ?? t.id;
  return focus ? `${base}?m=${focus}` : base;
}
