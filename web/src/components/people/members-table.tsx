"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { Avatar } from "@/components/avatar";
import { ErrorNote } from "@/components/form";
import { RoleBadge } from "@/components/status-pill";
import type { Profile } from "@/lib/queries";
import {
  isOffice,
  ROLE_LABELS,
  type AppRole,
} from "@/lib/status";
import { Constants } from "@/lib/database.types";
import { createClient } from "@/lib/supabase/client";

const ALL_ROLES = Constants.public.Enums.app_role;

export function MembersTable({
  members,
  currentUserId,
  currentRole,
}: {
  members: Profile[];
  currentUserId: string;
  currentRole: AppRole;
}) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const office = isOffice(currentRole);

  function canEditRole(member: Profile): boolean {
    if (!office) return false;
    // Owners cannot demote themselves; managers cannot touch owner rows.
    if (member.id === currentUserId && member.role === "owner") return false;
    if (member.role === "owner" && currentRole !== "owner") return false;
    return true;
  }

  function roleOptions(): AppRole[] {
    // Only an owner may grant the owner role.
    return ALL_ROLES.filter(
      (role) => role !== "owner" || currentRole === "owner"
    );
  }

  async function handleRoleChange(member: Profile, role: AppRole) {
    setError(null);
    setBusyId(member.id);
    const supabase = createClient();
    const { error: updateError } = await supabase
      .from("profiles")
      .update({ role })
      .eq("id", member.id);
    setBusyId(null);
    if (updateError) {
      setError(updateError.message);
      return;
    }
    router.refresh();
  }

  return (
    <section className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <ul className="divide-y divide-slate-100">
        {members.map((member) => (
          <li
            key={member.id}
            className="flex flex-wrap items-center gap-3 px-4 py-3"
          >
            <Avatar name={member.full_name} seed={member.id} />
            <div className="min-w-0 flex-1">
              <p className="truncate font-semibold text-slate-900">
                {member.full_name}
                {member.id === currentUserId && (
                  <span className="font-normal text-slate-400"> (you)</span>
                )}
              </p>
              <p className="text-xs text-slate-500">{member.phone ?? "—"}</p>
            </div>
            {canEditRole(member) ? (
              <select
                aria-label={`Role for ${member.full_name}`}
                value={member.role}
                disabled={busyId === member.id}
                onChange={(e) =>
                  handleRoleChange(member, e.target.value as AppRole)
                }
                className="min-h-11 rounded-lg border border-slate-300 bg-white px-2.5 py-2 text-sm font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-400/30 disabled:opacity-50"
              >
                {roleOptions().map((role) => (
                  <option key={role} value={role}>
                    {ROLE_LABELS[role]}
                  </option>
                ))}
                {!roleOptions().includes(member.role) && (
                  <option value={member.role} disabled>
                    {ROLE_LABELS[member.role]}
                  </option>
                )}
              </select>
            ) : (
              <RoleBadge role={member.role} />
            )}
          </li>
        ))}
      </ul>
      {error && (
        <div className="border-t border-slate-100 p-3">
          <ErrorNote message={error} />
        </div>
      )}
    </section>
  );
}
