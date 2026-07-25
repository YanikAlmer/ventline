"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { Avatar } from "@/components/avatar";
import { ErrorNote, secondaryButtonClass } from "@/components/form";
import { RoleBadge } from "@/components/status-pill";
import { useTranslator } from "@/i18n/client";
import type { Profile, ProjectMemberWithProfile } from "@/lib/queries";
import { isOffice, type AppRole } from "@/lib/status";
import { createClient } from "@/lib/supabase/client";

export function MembersPanel({
  projectId,
  members,
  companyMembers,
  role,
  currentUserId,
}: {
  projectId: string;
  members: ProjectMemberWithProfile[];
  companyMembers: Profile[];
  role: AppRole;
  currentUserId: string;
}) {
  const router = useRouter();
  const t = useTranslator();
  const [selected, setSelected] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const canManage = isOffice(role) || role === "foreman";
  const memberIds = new Set(members.map((m) => m.profile_id));
  // Foremen may only add workers (enforced by RLS too).
  const addable = companyMembers.filter(
    (p) =>
      !memberIds.has(p.id) && (isOffice(role) ? true : p.role === "worker")
  );

  async function handleAdd() {
    if (!selected) return;
    setError(null);
    setBusy(true);
    const supabase = createClient();
    const { error: insertError } = await supabase
      .from("project_members")
      .insert({ project_id: projectId, profile_id: selected });
    setBusy(false);
    if (insertError) {
      setError(insertError.message);
      return;
    }
    setSelected("");
    router.refresh();
  }

  async function handleRemove(profileId: string) {
    setError(null);
    setBusy(true);
    const supabase = createClient();
    const { error: deleteError } = await supabase
      .from("project_members")
      .delete()
      .eq("project_id", projectId)
      .eq("profile_id", profileId);
    setBusy(false);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    router.refresh();
  }

  return (
    <aside className="h-fit rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">
        {t("projects.members.title")}{" "}
        <span className="rounded-full bg-slate-200 px-2 py-0.5 text-xs font-bold text-slate-600">
          {members.length}
        </span>
      </h2>

      <ul className="space-y-2">
        {members.map((m) => (
          <li key={m.profile_id} className="flex items-center gap-3">
            <Avatar name={m.profiles.full_name} seed={m.profiles.id} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-slate-900">
                {m.profiles.full_name}
                {m.profile_id === currentUserId && (
                  <span className="text-slate-400">
                    {" "}
                    {t("projects.members.you")}
                  </span>
                )}
              </p>
              <RoleBadge role={m.profiles.role} />
            </div>
            {canManage && (
              <button
                type="button"
                onClick={() => handleRemove(m.profile_id)}
                disabled={
                  busy ||
                  (!isOffice(role) && m.profiles.role !== "worker")
                }
                title={t("projects.members.removeFromProject")}
                className="flex size-9 items-center justify-center rounded-full text-slate-400 hover:bg-red-50 hover:text-red-600 disabled:opacity-30"
              >
                ✕
              </button>
            )}
          </li>
        ))}
        {members.length === 0 && (
          <li className="text-sm text-slate-500">
            {t("projects.members.empty")}
          </li>
        )}
      </ul>

      {canManage && (
        <div className="mt-4 space-y-2 border-t border-slate-100 pt-4">
          <label
            htmlFor="add-member"
            className="block text-sm font-semibold text-slate-700"
          >
            {t("projects.members.addLabel")}
          </label>
          <select
            id="add-member"
            value={selected}
            onChange={(e) => setSelected(e.target.value)}
            className="block w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-400/30"
          >
            <option value="">{t("projects.members.selectPerson")}</option>
            {addable.map((p) => (
              <option key={p.id} value={p.id}>
                {p.full_name} ({t(`role.${p.role}`)})
              </option>
            ))}
          </select>
          <button
            type="button"
            onClick={handleAdd}
            disabled={!selected || busy}
            className={`${secondaryButtonClass} w-full`}
          >
            {t("projects.members.addToProject")}
          </button>
          <ErrorNote message={error} />
        </div>
      )}
    </aside>
  );
}
