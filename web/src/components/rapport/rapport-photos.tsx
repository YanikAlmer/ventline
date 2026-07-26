"use client";

import { useEffect, useRef, useState } from "react";

import { useTranslator } from "@/i18n/client";
import { downscaleImage } from "@/lib/image";
import { buildUploadPath, signedUrlMap } from "@/lib/storage";
import { createClient } from "@/lib/supabase/client";

type Photo = {
  id: string;
  storage_bucket: string;
  storage_path: string;
};

/**
 * Site photos on a Rapport.
 *
 * The database decides what is possible here and the UI only reflects it:
 * report_photos is frozen the moment the Rapport leaves 'draft', because the
 * photo paths are part of the canonical text the customer's signature attests
 * to. So a signed Rapport shows its photos and offers nothing else — an "add"
 * button the server would refuse is worse than no button.
 */
export function RapportPhotos({
  reportId,
  projectId,
  companyId,
  canEdit,
}: {
  reportId: string;
  projectId: string;
  companyId: string;
  canEdit: boolean;
}) {
  const t = useTranslator();
  const [photos, setPhotos] = useState<Photo[] | null>(null);
  const [urls, setUrls] = useState<Map<string, string>>(new Map());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  /** Bumped after a mutation; the effect below is the only place that reads. */
  const [version, setVersion] = useState(0);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      const supabase = createClient();
      const { data } = await supabase
        .from("attachments")
        .select("id, storage_bucket, storage_path")
        .eq("report_id", reportId)
        .order("created_at");
      if (cancelled) return;
      const rows = (data ?? []) as Photo[];
      // One batched call rather than one per thumbnail: a Rapport can carry
      // twenty photos and each signature is a round trip.
      const map = await signedUrlMap(
        supabase,
        "photos",
        rows.map((p) => p.storage_path),
      );
      if (cancelled) return;
      setPhotos(rows);
      setUrls(map);
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [reportId, version]);

  async function upload(files: FileList | null) {
    if (!files || files.length === 0) return;
    setBusy(true);
    setError(null);
    const supabase = createClient();
    try {
      for (const file of Array.from(files)) {
        const downscaled = await downscaleImage(file, t);
        const path = buildUploadPath(companyId, projectId, "photo.jpg");
        const { error: upErr } = await supabase.storage
          .from("photos")
          .upload(path, downscaled.blob, { contentType: "image/jpeg" });
        if (upErr) throw new Error(upErr.message);

        // The attachment is owned by the report, not borrowed from a chat
        // message: a message can be purged and its attachments cascade, which
        // would delete a photo out from under a signed document.
        const { data: row, error: insErr } = await supabase
          .from("attachments")
          .insert({
            report_id: reportId,
            kind: "photo",
            storage_bucket: "photos",
            storage_path: path,
            mime_type: "image/jpeg",
            byte_size: downscaled.blob.size,
            width: downscaled.width,
            height: downscaled.height,
          })
          .select("id")
          .single();
        if (insErr || !row) throw new Error(insErr?.message ?? "insert failed");

        const { error: linkErr } = await supabase
          .from("report_photos")
          .insert({ report_id: reportId, attachment_id: row.id });
        if (linkErr) throw new Error(linkErr.message);
      }
      setVersion((v) => v + 1);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setBusy(false);
      if (fileInput.current) fileInput.current.value = "";
    }
  }

  async function remove(photo: Photo) {
    setBusy(true);
    setError(null);
    const supabase = createClient();

    // Unlink first, then delete. report_photos references the attachment with
    // ON DELETE RESTRICT — deliberately, so a photo cannot vanish from under a
    // Rapport that cites it — so deleting the attachment first fails on the
    // foreign key even while the Rapport is still a draft.
    const { data: unlinked, error: unlinkError } = await supabase
      .from("report_photos")
      .delete()
      .eq("report_id", reportId)
      .eq("attachment_id", photo.id)
      .select("attachment_id");

    if (unlinkError) {
      // A signed Rapport raises from the freeze trigger and says why, in
      // German, from the database. Another company's row is merely invisible
      // and deletes nothing — the two are not the same refusal.
      setBusy(false);
      setError(unlinkError.message);
      return;
    }
    if ((unlinked ?? []).length === 0) {
      setBusy(false);
      setError(t("rapport.photos.frozen"));
      return;
    }

    await supabase.from("attachments").delete().eq("id", photo.id);
    // Best effort. Storage has no foreign keys, so a failure here leaves an
    // unreferenced object rather than a broken Rapport — worth attempting,
    // not worth failing the removal over.
    await supabase.storage.from(photo.storage_bucket).remove([photo.storage_path]);
    setBusy(false);
    setVersion((v) => v + 1);
  }

  if (photos === null) return null;
  if (photos.length === 0 && !canEdit) return null;

  return (
    <div>
      <h3 className="mb-1.5 text-xs font-bold uppercase tracking-wide text-slate-500">
        {t("rapport.photos.title")}
      </h3>

      {photos.length > 0 && (
        <ul className="mb-2 flex flex-wrap gap-2">
          {photos.map((photo) => {
            const url = urls.get(photo.storage_path);
            return (
              <li key={photo.id} className="group relative">
                {url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={url}
                    alt=""
                    className="size-20 rounded-lg border border-slate-200 object-cover"
                  />
                ) : (
                  <div className="size-20 rounded-lg bg-slate-100" />
                )}
                {canEdit && (
                  <button
                    type="button"
                    onClick={() => remove(photo)}
                    disabled={busy}
                    aria-label={t("rapport.photos.remove")}
                    className="absolute -right-1.5 -top-1.5 hidden size-6 items-center justify-center rounded-full border border-slate-300 bg-white text-xs text-slate-600 shadow-sm group-hover:flex hover:bg-red-50 hover:text-red-700"
                  >
                    ✕
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      )}

      {canEdit && (
        <>
          <input
            ref={fileInput}
            type="file"
            accept="image/*"
            multiple
            onChange={(event) => upload(event.target.files)}
            disabled={busy}
            className="block w-full text-xs text-slate-500 file:mr-3 file:rounded-lg file:border file:border-slate-300 file:bg-white file:px-3 file:py-1.5 file:text-xs file:font-semibold file:text-slate-700 hover:file:bg-slate-50"
          />
          <p className="mt-1 text-xs text-slate-400">
            {t("rapport.photos.note")}
          </p>
        </>
      )}

      {error && <p className="mt-1 text-xs text-red-700">{error}</p>}
    </div>
  );
}
