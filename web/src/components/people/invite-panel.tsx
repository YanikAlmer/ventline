"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import {
  ErrorNote,
  inputClass,
  labelClass,
  primaryButtonClass,
} from "@/components/form";
import { relativeTime } from "@/lib/format";
import type { OpenInvite } from "@/lib/queries";
import { ROLE_LABELS, type AppRole } from "@/lib/status";
import { createClient } from "@/lib/supabase/client";

const INVITABLE_ROLES: AppRole[] = [
  "owner",
  "manager",
  "foreman",
  "worker",
  "customer",
];

type ProjectOption = { id: string; name: string };

export function InvitePanel({
  invites,
  projects,
  currentRole,
}: {
  invites: OpenInvite[];
  projects: ProjectOption[];
  currentRole: AppRole;
}) {
  const router = useRouter();
  const [role, setRole] = useState<AppRole>("worker");
  const [fullName, setFullName] = useState("");
  const [projectIds, setProjectIds] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [newCode, setNewCode] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const roles = INVITABLE_ROLES.filter(
    (r) => r !== "owner" || currentRole === "owner"
  );

  function toggleProject(id: string) {
    setProjectIds((prev) =>
      prev.includes(id) ? prev.filter((p) => p !== id) : [...prev, id]
    );
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    setNewCode(null);
    setCopied(false);
    const supabase = createClient();

    const { data, error: rpcError } = await supabase.rpc("create_invite", {
      p_role: role,
      p_full_name: fullName.trim() || undefined,
      p_project_ids: projectIds,
    });
    setBusy(false);
    if (rpcError || !data || data.length === 0) {
      setError(rpcError?.message ?? "Could not create the invite.");
      return;
    }

    setNewCode(data[0].code);
    setFullName("");
    setProjectIds([]);
    router.refresh();
  }

  async function handleCopy() {
    if (!newCode) return;
    await navigator.clipboard.writeText(newCode);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  async function handleRevoke(inviteId: string) {
    setError(null);
    const supabase = createClient();
    const { error: deleteError } = await supabase
      .from("invites")
      .delete()
      .eq("id", inviteId);
    if (deleteError) {
      setError(deleteError.message);
      return;
    }
    router.refresh();
  }

  return (
    <section className="mt-8">
      <h2 className="mb-3 text-lg font-bold text-slate-900">Invites</h2>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <form
          onSubmit={handleCreate}
          className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
        >
          <div>
            <label htmlFor="inv-role" className={labelClass}>
              Role
            </label>
            <select
              id="inv-role"
              className={inputClass}
              value={role}
              onChange={(e) => setRole(e.target.value as AppRole)}
            >
              {roles.map((r) => (
                <option key={r} value={r}>
                  {ROLE_LABELS[r]}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label htmlFor="inv-name" className={labelClass}>
              Name <span className="font-normal text-slate-400">(optional)</span>
            </label>
            <input
              id="inv-name"
              className={inputClass}
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="Who is this invite for?"
            />
          </div>

          <fieldset>
            <legend className={labelClass}>
              Add to projects{" "}
              {role === "customer" && (
                <span className="font-normal text-rose-600">
                  (required for customers to see anything)
                </span>
              )}
            </legend>
            {projects.length === 0 ? (
              <p className="text-sm text-slate-500">No projects yet.</p>
            ) : (
              <div className="max-h-40 space-y-1 overflow-y-auto rounded-lg border border-slate-200 p-2">
                {projects.map((p) => (
                  <label
                    key={p.id}
                    className="flex min-h-10 cursor-pointer items-center gap-3 rounded-md px-2 py-1.5 hover:bg-slate-50"
                  >
                    <input
                      type="checkbox"
                      checked={projectIds.includes(p.id)}
                      onChange={() => toggleProject(p.id)}
                      className="size-4 accent-slate-900"
                    />
                    <span className="text-sm font-medium text-slate-800">
                      {p.name}
                    </span>
                  </label>
                ))}
              </div>
            )}
          </fieldset>

          <ErrorNote message={error} />

          <button type="submit" disabled={busy} className={`${primaryButtonClass} w-full`}>
            {busy ? "Creating…" : "Create invite"}
          </button>

          {newCode && (
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-center">
              <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-emerald-700">
                Invite code
              </p>
              <p className="font-mono text-3xl font-black tracking-[0.3em] text-emerald-900">
                {newCode}
              </p>
              <button
                type="button"
                onClick={handleCopy}
                className="mt-2 rounded-lg bg-emerald-700 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-800"
              >
                {copied ? "Copied ✓" : "Copy code"}
              </button>
            </div>
          )}
        </form>

        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <h3 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">
            Open invites
          </h3>
          {invites.length === 0 ? (
            <p className="text-sm text-slate-500">No open invites.</p>
          ) : (
            <ul className="divide-y divide-slate-100">
              {invites.map((invite) => {
                const expired = new Date(invite.expires_at) < new Date();
                return (
                  <li
                    key={invite.id}
                    className="flex items-center gap-3 py-2.5"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="font-mono text-sm font-bold tracking-widest text-slate-900">
                        {invite.code}
                      </p>
                      <p className="text-xs text-slate-500">
                        {ROLE_LABELS[invite.role]}
                        {invite.full_name ? ` · ${invite.full_name}` : ""} ·{" "}
                        {expired ? (
                          <span className="font-semibold text-red-600">
                            expired
                          </span>
                        ) : (
                          `expires ${new Date(invite.expires_at).toLocaleDateString()}`
                        )}
                        {" · created "}
                        {relativeTime(invite.created_at)}
                      </p>
                    </div>
                    <button
                      type="button"
                      onClick={() => handleRevoke(invite.id)}
                      className="rounded-lg border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-700 hover:bg-red-50"
                    >
                      Revoke
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </div>
    </section>
  );
}
