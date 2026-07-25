"use client";

import { useEffect, useRef, useState } from "react";

import { ErrorNote, secondaryButtonClass } from "@/components/form";
import { useTranslator } from "@/i18n/client";
import { downscaleImage, jpegFilename } from "@/lib/image";
import type { TaskAttachment } from "@/lib/queries";
import { buildUploadPath, signedUrlMap } from "@/lib/storage";
import { createClient } from "@/lib/supabase/client";

/** Matches the video bucket's allowed_mime_types. */
const VIDEO_TYPES = ["video/mp4", "video/quicktime"];
/** Matches the video bucket's file_size_limit. */
const MAX_VIDEO_BYTES = 200 * 1024 * 1024;

/**
 * Photos and videos attached to the work itself rather than to a chat message
 * — the plan, the nameplate, the "this is how it was before" clip. Kept next
 * to the task so it survives the conversation scrolling away.
 */
export function TaskFiles({
  taskId,
  companyId,
  projectId,
  initial,
  currentUserId,
  canEdit,
}: {
  taskId: string;
  companyId: string;
  projectId: string;
  initial: TaskAttachment[];
  currentUserId: string;
  canEdit: boolean;
}) {
  const t = useTranslator();
  const [items, setItems] = useState<TaskAttachment[]>(initial);
  const [urls, setUrls] = useState<Map<string, string>>(new Map());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Signed URLs expire, and the set changes as files are added or removed, so
  // they are minted here rather than passed down from the server render.
  useEffect(() => {
    let cancelled = false;
    async function sign() {
      const supabase = createClient();
      const buckets = [...new Set(items.map((a) => a.storage_bucket))];
      const merged = new Map<string, string>();
      for (const bucket of buckets) {
        const paths = items
          .filter((a) => a.storage_bucket === bucket)
          .map((a) => a.storage_path);
        const signed = await signedUrlMap(supabase, bucket, paths);
        for (const [path, url] of signed) merged.set(path, url);
      }
      if (!cancelled) setUrls(merged);
    }
    if (items.length > 0) void sign();
    return () => {
      cancelled = true;
    };
  }, [items]);

  async function handleUpload(list: FileList | null) {
    if (!list || list.length === 0) return;
    setBusy(true);
    setError(null);
    const supabase = createClient();

    try {
      const added: TaskAttachment[] = [];
      for (const file of Array.from(list)) {
        const isVideo = file.type.startsWith("video/");
        let path: string;
        let row: {
          kind: "photo" | "video";
          storage_bucket: string;
          mime_type: string;
          byte_size: number;
          width?: number;
          height?: number;
        };

        if (isVideo) {
          if (!VIDEO_TYPES.includes(file.type)) {
            throw new Error(t("tasks.files.videoType"));
          }
          if (file.size > MAX_VIDEO_BYTES) {
            throw new Error(t("tasks.files.videoTooLarge"));
          }
          path = buildUploadPath(companyId, projectId, file.name);
          const { error: uploadError } = await supabase.storage
            .from("video")
            .upload(path, file, { contentType: file.type });
          if (uploadError) throw new Error(uploadError.message);
          row = {
            kind: "video",
            storage_bucket: "video",
            mime_type: file.type,
            byte_size: file.size,
          };
        } else {
          const { blob, width, height } = await downscaleImage(file, t);
          path = buildUploadPath(companyId, projectId, jpegFilename(file.name));
          const { error: uploadError } = await supabase.storage
            .from("photos")
            .upload(path, blob, { contentType: "image/jpeg" });
          if (uploadError) throw new Error(uploadError.message);
          row = {
            kind: "photo",
            storage_bucket: "photos",
            mime_type: "image/jpeg",
            byte_size: blob.size,
            width,
            height,
          };
        }

        const { data, error: insertError } = await supabase
          .from("attachments")
          .insert({ task_id: taskId, storage_path: path, ...row })
          .select("*")
          .single();
        if (insertError || !data) {
          throw new Error(insertError?.message ?? t("tasks.files.uploadFailed"));
        }
        added.push(data);
      }
      setItems((prev) => [...prev, ...added]);
    } catch (err) {
      setError(err instanceof Error ? err.message : t("tasks.files.uploadFailed"));
    } finally {
      setBusy(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  async function handleDelete(attachment: TaskAttachment) {
    setError(null);
    const supabase = createClient();
    const { error: deleteError } = await supabase
      .from("attachments")
      .delete()
      .eq("id", attachment.id);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    // RLS answers a forbidden delete with "0 rows affected", not an error, so
    // confirm the row is actually gone before removing it from the list.
    const { count } = await supabase
      .from("attachments")
      .select("id", { count: "exact", head: true })
      .eq("id", attachment.id);
    if (count && count > 0) {
      setError(t("tasks.files.deleteForbidden"));
      return;
    }
    setItems((prev) => prev.filter((a) => a.id !== attachment.id));
  }

  return (
    <section className="mb-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div className="mb-3 flex items-center justify-between gap-3">
        <h2 className="text-sm font-bold uppercase tracking-wide text-slate-500">
          {t("tasks.files.title")}{" "}
          <span className="text-slate-400">{items.length}</span>
        </h2>
        {canEdit && (
          <>
            <input
              ref={inputRef}
              type="file"
              accept="image/*,video/mp4,video/quicktime"
              multiple
              className="hidden"
              onChange={(e) => void handleUpload(e.target.files)}
            />
            <button
              type="button"
              disabled={busy}
              onClick={() => inputRef.current?.click()}
              className={`${secondaryButtonClass} min-h-9 px-3 py-1.5 text-xs`}
            >
              {busy ? t("tasks.files.uploading") : `+ ${t("tasks.files.add")}`}
            </button>
          </>
        )}
      </div>

      <ErrorNote message={error} />

      {items.length === 0 ? (
        <p className="text-sm text-slate-500">{t("tasks.files.none")}</p>
      ) : (
        <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
          {items.map((attachment) => {
            const url = urls.get(attachment.storage_path);
            const mine = attachment.uploaded_by === currentUserId;
            return (
              <li
                key={attachment.id}
                className="group relative overflow-hidden rounded-xl border border-slate-200 bg-slate-50"
              >
                {attachment.kind === "video" ? (
                  url ? (
                    <video
                      src={url}
                      controls
                      playsInline
                      preload="metadata"
                      className="aspect-square w-full bg-black object-contain"
                    />
                  ) : (
                    <div className="flex aspect-square items-center justify-center text-2xl">
                      🎬
                    </div>
                  )
                ) : url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={url}
                    alt={attachment.caption ?? ""}
                    className="aspect-square w-full object-cover"
                  />
                ) : (
                  <div className="aspect-square w-full animate-pulse bg-slate-200" />
                )}

                {canEdit && mine && (
                  <button
                    type="button"
                    onClick={() => void handleDelete(attachment)}
                    aria-label={t("tasks.files.delete")}
                    className="absolute right-1.5 top-1.5 rounded-full bg-black/60 px-2 py-1 text-xs font-bold text-white opacity-0 transition-opacity group-hover:opacity-100 focus:opacity-100"
                  >
                    ✕
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
