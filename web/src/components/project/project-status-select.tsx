"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { ProjectStatusPill } from "@/components/status-pill";
import { useTranslator } from "@/i18n/client";
import { PROJECT_STATUSES, type ProjectStatus } from "@/lib/status";
import { createClient } from "@/lib/supabase/client";

export function ProjectStatusSelect({
  projectId,
  status,
  editable,
}: {
  projectId: string;
  status: ProjectStatus;
  editable: boolean;
}) {
  const router = useRouter();
  const t = useTranslator();
  const [busy, setBusy] = useState(false);

  if (!editable) return <ProjectStatusPill status={status} />;

  async function handleChange(next: ProjectStatus) {
    setBusy(true);
    const supabase = createClient();
    const { error } = await supabase
      .from("projects")
      .update({ status: next })
      .eq("id", projectId);
    setBusy(false);
    if (error) {
      alert(t("projects.status.updateFailed", { message: error.message }));
      return;
    }
    router.refresh();
  }

  return (
    <label className="inline-flex items-center gap-2">
      <ProjectStatusPill status={status} />
      <select
        aria-label={t("projects.status.label")}
        value={status}
        disabled={busy}
        onChange={(e) => handleChange(e.target.value as ProjectStatus)}
        className="min-h-11 rounded-lg border border-slate-300 bg-white px-2.5 py-2 text-sm font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-400/30 disabled:opacity-50"
      >
        {PROJECT_STATUSES.map((s) => (
          <option key={s} value={s}>
            {t(`status.project.${s}`)}
          </option>
        ))}
      </select>
    </label>
  );
}
