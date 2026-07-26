import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { ExportPanel } from "@/components/export/export-panel";
import { getTranslator } from "@/i18n/server";
import { getCurrentUser } from "@/lib/queries";
import { isOffice } from "@/lib/status";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("export.title") };
}

export default async function ExportPage() {
  const supabase = await createClient();
  const current = await getCurrentUser(supabase);
  if (!current) return null;

  // The RPC refuses a worker on its own — this only spares them a page whose
  // every control would fail.
  if (!isOffice(current.profile.role)) notFound();

  return (
    <div className="mx-auto max-w-4xl px-4 py-6 sm:px-6">
      <ExportPanel />
    </div>
  );
}
