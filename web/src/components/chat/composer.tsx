"use client";

import { useEffect, useRef, useState } from "react";

import { useTranslator } from "@/i18n/client";
import type { PendingAnnotation } from "@/lib/annotations";
import {
  findTrigger,
  mentionsPayload,
  refsPayload,
  resolveAnnotations,
} from "@/lib/annotations";
import { downscaleImage, jpegFilename } from "@/lib/image";
import { isVideoFile, videoRejectionKey } from "@/lib/media";
import { buildUploadPath } from "@/lib/storage";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/lib/database.types";

type Candidate = {
  id: string;
  /** The run inserted into the body, sigil included. */
  text: string;
  label: string;
  hint: string | null;
};

export function Composer({
  companyId,
  projectId,
  taskId,
  onSent,
}: {
  companyId: string;
  projectId: string;
  taskId: string | null;
  onSent: (messageId: string) => void;
}) {
  const t = useTranslator();
  const [body, setBody] = useState("");
  const [files, setFiles] = useState<File[]>([]);
  const [shareWithCustomer, setShareWithCustomer] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  /**
   * What has been picked, not where it sits. Offsets are derived from the
   * final text at send time — see resolveAnnotations — so editing around a
   * mention cannot desynchronise a range nobody can see.
   */
  const [pending, setPending] = useState<PendingAnnotation[]>([]);
  const [trigger, setTrigger] = useState<ReturnType<typeof findTrigger>>(null);
  const [highlighted, setHighlighted] = useState(0);
  /**
   * Suggestions are stamped with the token they answer. Without that, opening
   * a new "@..." shows the previous list for the length of the debounce — long
   * enough to pick the wrong person.
   */
  const [suggestions, setSuggestions] = useState<{
    token: string;
    items: Candidate[];
  }>({ token: "", items: [] });

  const token = trigger ? `${trigger.sigil}${trigger.query}` : "";
  const candidates = suggestions.token === token ? suggestions.items : [];

  // Debounced: someone typing "@Wanda" would otherwise fire six queries, and
  // the last one is the only one whose answer is still on screen.
  useEffect(() => {
    if (!trigger) return;
    let cancelled = false;
    const timer = setTimeout(async () => {
      const supabase = createClient();
      if (trigger.sigil === "@") {
        const { data } = await supabase.rpc("mention_candidates", {
          p_project_id: projectId,
          p_query: trigger.query,
        });
        if (cancelled) return;
        setSuggestions({
          token: `@${trigger.query}`,
          items: (data ?? []).map((row) => ({
            id: row.profile_id,
            text: `@${row.full_name}`,
            label: row.full_name,
            hint: row.is_member ? null : t("chat.mention.office"),
          })),
        });
      } else {
        const { data } = await supabase.rpc("task_ref_candidates", {
          p_project_id: projectId,
          p_query: trigger.query,
        });
        if (cancelled) return;
        setSuggestions({
          token: `#${trigger.query}`,
          items: (data ?? []).map((row) => ({
            id: row.task_id,
            text: `#${row.title}`,
            label: row.title,
            hint: row.parent_title,
          })),
        });
      }
      setHighlighted(0);
    }, 150);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [trigger, projectId, t]);

  function syncTrigger(element: HTMLTextAreaElement) {
    // selectionStart, not the text length: the picker has to follow the caret
    // when someone goes back to fix a name in the middle of a sentence.
    setTrigger(findTrigger(element.value, element.selectionStart ?? 0));
  }

  function choose(candidate: Candidate) {
    if (!trigger) return;
    const element = textareaRef.current;
    // The run being replaced comes entirely from the trigger, which was
    // computed from one consistent (value, caret) pair. Reading
    // selectionStart again here looks equivalent and is not: picking with the
    // mouse can leave the textarea's selection where it was several
    // keystrokes ago, and slicing the tail at a stale caret duplicates
    // everything typed since — observed as "…#Kondensatpumpe montieren bitte
    // #Kondensat".
    const runEnd = trigger.start + 1 + trigger.query.length;
    // A trailing space so the next word does not glue itself onto the name and
    // break the exact-run match at send time.
    const inserted = `${candidate.text} `;
    const next = body.slice(0, trigger.start) + inserted + body.slice(runEnd);

    setBody(next);
    setPending((prev) => [
      ...prev,
      { kind: trigger.sigil === "@" ? "mention" : "task", id: candidate.id, text: candidate.text },
    ]);
    setTrigger(null);

    const position = trigger.start + inserted.length;
    requestAnimationFrame(() => {
      element?.focus();
      element?.setSelectionRange(position, position);
    });
  }

  function handlePickFiles(list: FileList | null) {
    if (!list) return;
    const picked = Array.from(list);

    // Checked here rather than on send: the bucket would reject it anyway, but
    // only after the person has watched an upload bar crawl across the screen.
    const rejected = picked
      .map((file) => (isVideoFile(file) ? videoRejectionKey(file) : null))
      .find(Boolean);
    if (rejected) {
      setError(t(rejected));
      if (fileInputRef.current) fileInputRef.current.value = "";
      return;
    }

    setError(null);
    setFiles((prev) => [...prev, ...picked].slice(0, 10));
    if (fileInputRef.current) fileInputRef.current.value = "";
  }

  async function handleSend(e: React.FormEvent) {
    e.preventDefault();
    const text = body.trim();
    if (!text && files.length === 0) return;

    setBusy(true);
    setError(null);
    const supabase = createClient();

    try {
      const attachments: Json[] = [];
      // Tracked alongside rather than read back out of the Json blobs: the
      // message row needs one kind, and digging it out of an opaque payload
      // would mean casting away the very type that keeps it honest.
      const kinds: ("photo" | "video")[] = [];
      for (const file of files) {
        if (isVideoFile(file)) {
          // Uploaded as-is. Re-encoding in the browser would take longer than
          // the upload and lose quality the crew may be relying on.
          const path = buildUploadPath(companyId, projectId, file.name);
          const { error: uploadError } = await supabase.storage
            .from("video")
            .upload(path, file, { contentType: file.type });
          if (uploadError) {
            throw new Error(
              t("chat.photoUploadFailed", { message: uploadError.message })
            );
          }
          kinds.push("video");
          attachments.push({
            kind: "video",
            storage_bucket: "video",
            storage_path: path,
            mime_type: file.type,
            byte_size: file.size,
          });
          continue;
        }

        const { blob, width, height } = await downscaleImage(file, t);
        const path = buildUploadPath(
          companyId,
          projectId,
          jpegFilename(file.name)
        );
        const { error: uploadError } = await supabase.storage
          .from("photos")
          .upload(path, blob, { contentType: "image/jpeg" });
        if (uploadError) {
          throw new Error(
            t("chat.photoUploadFailed", { message: uploadError.message })
          );
        }
        kinds.push("photo");
        attachments.push({
          kind: "photo",
          storage_bucket: "photos",
          storage_path: path,
          mime_type: "image/jpeg",
          byte_size: blob.size,
          width,
          height,
        });
      }

      // Resolved against the text actually being sent, so anything edited
      // away simply does not notify.
      const resolved = resolveAnnotations(text, pending);

      const { data: messageId, error: rpcError } = await supabase.rpc(
        "send_message",
        {
          p_project_id: projectId,
          p_task_id: taskId ?? undefined,
          // messages.kind is one value for the row, so a batch takes the kind
          // of what it leads with. The attachments carry their own kinds and
          // the bubble renders each accordingly, so a mixed send is not lost —
          // it only affects which icon the inbox preview shows.
          p_kind: kinds[0] ?? "text",
          p_body: text || undefined,
          p_attachments: attachments,
          p_shared_with_customer: shareWithCustomer,
          p_mentions: mentionsPayload(resolved),
          p_refs: refsPayload(resolved),
        }
      );
      if (rpcError || !messageId) {
        throw new Error(rpcError?.message ?? t("chat.sendFailed"));
      }

      setBody("");
      setFiles([]);
      setPending([]);
      setShareWithCustomer(false);
      onSent(messageId);
    } catch (err) {
      setError(err instanceof Error ? err.message : t("chat.sendFailed"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form
      onSubmit={handleSend}
      className="border-t border-slate-200 bg-white p-3"
    >
      {files.length > 0 && (
        <div className="mb-2 flex flex-wrap gap-2">
          {files.map((file, i) => (
            <span
              key={`${file.name}-${i}`}
              className="inline-flex items-center gap-2 rounded-full bg-slate-100 px-3 py-1.5 text-xs font-semibold text-slate-700"
            >
              {isVideoFile(file) ? "🎬" : "📷"} {file.name}
              <button
                type="button"
                aria-label={t("chat.removeAttachment", { name: file.name })}
                onClick={() =>
                  setFiles((prev) => prev.filter((_, idx) => idx !== i))
                }
                className="text-slate-400 hover:text-red-600"
              >
                ✕
              </button>
            </span>
          ))}
        </div>
      )}

      {error && (
        <p className="mb-2 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
          {error}
        </p>
      )}

      {/* Above the textarea, not below: on a laptop the composer already sits
          at the bottom of the viewport, and a dropdown would open off-screen. */}
      {trigger && candidates.length > 0 && (
        <ul
          role="listbox"
          aria-label={t(
            trigger.sigil === "@" ? "chat.mention.people" : "chat.mention.tasks",
          )}
          className="mb-2 max-h-56 overflow-y-auto rounded-xl border border-slate-200 bg-white py-1 shadow-lg"
        >
          {candidates.map((candidate, index) => (
            <li key={candidate.id}>
              <button
                type="button"
                role="option"
                aria-selected={index === highlighted}
                // onMouseDown, not onClick: the textarea loses focus first
                // otherwise, and the caret position we insert at is gone.
                onMouseDown={(event) => {
                  event.preventDefault();
                  choose(candidate);
                }}
                onMouseEnter={() => setHighlighted(index)}
                className={`flex w-full items-baseline gap-2 px-3 py-2 text-left text-sm ${
                  index === highlighted ? "bg-slate-100" : "hover:bg-slate-50"
                }`}
              >
                <span className="font-semibold text-slate-900">
                  {trigger.sigil}
                  {candidate.label}
                </span>
                {candidate.hint && (
                  <span className="truncate text-xs text-slate-500">
                    {candidate.hint}
                  </span>
                )}
              </button>
            </li>
          ))}
        </ul>
      )}

      <div className="flex items-end gap-2">
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*,video/mp4,video/quicktime"
          multiple
          className="hidden"
          onChange={(e) => handlePickFiles(e.target.files)}
        />
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          title={t("chat.attachPhotos")}
          aria-label={t("chat.attachPhotos")}
          className="flex size-11 shrink-0 items-center justify-center rounded-xl border border-slate-300 text-lg hover:bg-slate-50"
        >
          📷
        </button>
        <textarea
          ref={textareaRef}
          value={body}
          onChange={(e) => {
            setBody(e.target.value);
            syncTrigger(e.currentTarget);
          }}
          // The caret can move without the text changing — arrow keys, a
          // click into the middle of a sentence — and the picker has to follow.
          onClick={(e) => syncTrigger(e.currentTarget)}
          onKeyUp={(e) => syncTrigger(e.currentTarget)}
          onBlur={() => setTrigger(null)}
          onKeyDown={(e) => {
            const picking = trigger && candidates.length > 0;
            if (picking) {
              if (e.key === "ArrowDown") {
                e.preventDefault();
                setHighlighted((i) => (i + 1) % candidates.length);
                return;
              }
              if (e.key === "ArrowUp") {
                e.preventDefault();
                setHighlighted(
                  (i) => (i - 1 + candidates.length) % candidates.length,
                );
                return;
              }
              // Enter and Tab commit the highlighted candidate. Enter would
              // otherwise send a message with a half-typed name in it, which
              // is the single most annoying way for this feature to fail.
              if (e.key === "Enter" || e.key === "Tab") {
                e.preventDefault();
                choose(candidates[highlighted]);
                return;
              }
              if (e.key === "Escape") {
                e.preventDefault();
                setTrigger(null);
                return;
              }
            }
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              e.currentTarget.form?.requestSubmit();
            }
          }}
          rows={1}
          placeholder={t("chat.composerPlaceholder")}
          className="max-h-36 min-h-11 flex-1 resize-y rounded-xl border border-slate-300 px-3.5 py-2.5 text-sm focus:border-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-400/30"
        />
        <button
          type="submit"
          disabled={busy || (!body.trim() && files.length === 0)}
          className="flex h-11 shrink-0 items-center justify-center rounded-xl bg-slate-900 px-4 text-sm font-semibold text-white hover:bg-slate-700 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {busy ? t("chat.sending") : t("common.send")}
        </button>
      </div>

      <label className="mt-2 flex min-h-8 w-fit cursor-pointer items-center gap-2 text-xs font-semibold text-slate-600">
        <input
          type="checkbox"
          checked={shareWithCustomer}
          onChange={(e) => setShareWithCustomer(e.target.checked)}
          className="size-4 accent-rose-600"
        />
        {t("chat.shareWithCustomer")}
      </label>
    </form>
  );
}
