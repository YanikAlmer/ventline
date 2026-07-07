import type { Metadata } from "next";

import { InvitePanel } from "@/components/people/invite-panel";
import { MembersTable } from "@/components/people/members-table";
import {
  getCompanyMembers,
  getCurrentUser,
  getOpenInvites,
} from "@/lib/queries";
import { isOffice } from "@/lib/status";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "People" };

export default async function PeoplePage() {
  const supabase = await createClient();
  const current = await getCurrentUser(supabase);
  if (!current) return null;

  const office = isOffice(current.profile.role);
  const [members, invites, projectsResult] = await Promise.all([
    getCompanyMembers(supabase),
    office ? getOpenInvites(supabase) : Promise.resolve([]),
    office
      ? supabase.from("projects").select("id, name").order("name")
      : Promise.resolve({ data: [] }),
  ]);

  return (
    <div className="mx-auto max-w-4xl px-4 py-6 sm:px-6">
      <h1 className="mb-1 text-2xl font-black tracking-tight text-slate-900">
        People
      </h1>
      <p className="mb-6 text-sm text-slate-500">
        Everyone at {current.company.name}
      </p>

      <MembersTable
        members={members}
        currentUserId={current.userId}
        currentRole={current.profile.role}
      />

      {office && (
        <InvitePanel
          invites={invites}
          projects={projectsResult.data ?? []}
          currentRole={current.profile.role}
        />
      )}
    </div>
  );
}
