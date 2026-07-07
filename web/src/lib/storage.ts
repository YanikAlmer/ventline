import type { SupabaseClient } from "@supabase/supabase-js";

import type { Database } from "@/lib/database.types";

export const SIGNED_URL_TTL_SECONDS = 60 * 60; // 60 minutes

type AnyClient = SupabaseClient<Database>;

/** Signed URL for a private storage object, or null when unavailable. */
export async function signedUrl(
  supabase: AnyClient,
  bucket: string,
  path: string | null | undefined
): Promise<string | null> {
  if (!path) return null;
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrl(path, SIGNED_URL_TTL_SECONDS);
  if (error) return null;
  return data.signedUrl;
}

/** Batch-sign many paths in one bucket. Returns a path -> url map. */
export async function signedUrlMap(
  supabase: AnyClient,
  bucket: string,
  paths: string[]
): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  const unique = [...new Set(paths.filter(Boolean))];
  if (unique.length === 0) return map;
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrls(unique, SIGNED_URL_TTL_SECONDS);
  if (error || !data) return map;
  for (const entry of data) {
    if (entry.signedUrl && entry.path) map.set(entry.path, entry.signedUrl);
  }
  return map;
}

/**
 * Storage object path for an upload. RLS validates the first two segments:
 * `{company_id}/{project_id}/{uuid}/{filename}`.
 */
export function buildUploadPath(
  companyId: string,
  projectId: string,
  filename: string
): string {
  const safeName = filename.replace(/[^\w.\-]+/g, "_").slice(-100) || "file";
  return `${companyId}/${projectId}/${crypto.randomUUID()}/${safeName}`;
}
