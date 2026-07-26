import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { RapportPanel } from "@/components/rapport/rapport-panel";
import { getTranslator } from "@/i18n/server";
import { getCurrentUser } from "@/lib/queries";
import {
  getDivergences,
  getProjectMaterials,
  getProjectReports,
  getProjectTime,
} from "@/lib/rapport";
import { isOffice } from "@/lib/status";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("rapport.list.title") };
}

export default async function RapportePage(props: {
  params: Promise<{ projectId: string }>;
}) {
  const { projectId } = await props.params;
  const t = await getTranslator();
  const supabase = await createClient();

  const [current, projectResult] = await Promise.all([
    getCurrentUser(supabase),
    supabase.from("projects").select("*").eq("id", projectId).maybeSingle(),
  ]);
  if (!current) return null;
  const project = projectResult.data;
  if (!project) notFound();

  const [reports, timeEntries, materials, divergences, customersResult] =
    await Promise.all([
      getProjectReports(supabase, projectId),
      getProjectTime(supabase, projectId),
      getProjectMaterials(supabase, projectId),
      getDivergences(supabase),
      supabase.from("customers").select("*").order("name"),
    ]);

  return (
    <div className="mx-auto max-w-4xl px-4 py-6 sm:px-6">
      <nav className="mb-4 text-sm text-slate-500">
        <Link href="/" className="font-semibold hover:text-slate-900">
          {t("nav.projects")}
        </Link>{" "}
        /{" "}
        <Link
          href={`/projects/${projectId}`}
          className="font-semibold hover:text-slate-900"
        >
          {project.name}
        </Link>{" "}
        / <span className="text-slate-700">{t("rapport.list.title")}</span>
      </nav>

      <RapportPanel
        reports={reports}
        timeEntries={timeEntries}
        materials={materials}
        divergences={divergences.filter((d) => d.project_id === projectId)}
        customers={customersResult.data ?? []}
        canInvoice={isOffice(current.profile.role)}
        siteUrl={process.env.NEXT_PUBLIC_SITE_URL ?? ""}
      />
    </div>
  );
}
