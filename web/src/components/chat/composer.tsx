"use client";

import { useRef, useState } from "react";

import { downscaleImage, jpegFilename } from "@/lib/image";
import { buildUploadPath } from "@/lib/storage";
import { createClient } from "@/lib/supabase/client";
import type { Json } from "@/lib/database.types";

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
  const [body, setBody] = useState("");
  const [files, setFiles] = useState<File[]>([]);
  const [shareWithCustomer, setShareWithCustomer] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  function handlePickFiles(list: FileList | null) {
    if (!list) return;
    setFiles((prev) => [...prev, ...Array.from(list)].slice(0, 10));
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
      for (const file of files) {
        const { blob, width, height } = await downscaleImage(file);
        const path = buildUploadPath(
          companyId,
          projectId,
          jpegFilename(file.name)
        );
        const { error: uploadError } = await supabase.storage
          .from("photos")
          .upload(path, blob, { contentType: "image/jpeg" });
        if (uploadError) {
          throw new Error(`Photo upload failed: ${uploadError.message}`);
        }
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

      const { data: messageId, error: rpcError } = await supabase.rpc(
        "send_message",
        {
          p_project_id: projectId,
          p_task_id: taskId ?? undefined,
          p_kind: attachments.length > 0 ? "photo" : "text",
          p_body: text || undefined,
          p_attachments: attachments,
          p_shared_with_customer: shareWithCustomer,
        }
      );
      if (rpcError || !messageId) {
        throw new Error(rpcError?.message ?? "Sending failed.");
      }

      setBody("");
      setFiles([]);
      setShareWithCustomer(false);
      onSent(messageId);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sending failed.");
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
              📷 {file.name}
              <button
                type="button"
                aria-label={`Remove ${file.name}`}
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

      <div className="flex items-end gap-2">
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          multiple
          className="hidden"
          onChange={(e) => handlePickFiles(e.target.files)}
        />
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          title="Attach photos"
          aria-label="Attach photos"
          className="flex size-11 shrink-0 items-center justify-center rounded-xl border border-slate-300 text-lg hover:bg-slate-50"
        >
          📷
        </button>
        <textarea
          value={body}
          onChange={(e) => setBody(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              e.currentTarget.form?.requestSubmit();
            }
          }}
          rows={1}
          placeholder="Write a message…"
          className="max-h-36 min-h-11 flex-1 resize-y rounded-xl border border-slate-300 px-3.5 py-2.5 text-sm focus:border-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-400/30"
        />
        <button
          type="submit"
          disabled={busy || (!body.trim() && files.length === 0)}
          className="flex h-11 shrink-0 items-center justify-center rounded-xl bg-slate-900 px-4 text-sm font-semibold text-white hover:bg-slate-700 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {busy ? "Sending…" : "Send"}
        </button>
      </div>

      <label className="mt-2 flex min-h-8 w-fit cursor-pointer items-center gap-2 text-xs font-semibold text-slate-600">
        <input
          type="checkbox"
          checked={shareWithCustomer}
          onChange={(e) => setShareWithCustomer(e.target.checked)}
          className="size-4 accent-rose-600"
        />
        Share with customer
      </label>
    </form>
  );
}
