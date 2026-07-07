import type { Database, Tables } from "@/lib/database.types";
import type { ServerClient } from "@/lib/supabase/server";

export type Profile = Tables<"profiles">;
export type Company = Tables<"companies">;
export type Project = Tables<"projects">;
export type ProjectOverview = Tables<"project_overview">;
export type Task = Tables<"tasks">;
export type Invite = Tables<"invites">;
export type ProjectStatus = Database["public"]["Enums"]["project_status"];

export type CurrentUser = {
  userId: string;
  email: string | null;
  profile: Profile;
  company: Company;
};

/**
 * Authenticated user's profile + company, or null when the auth user has no
 * profile row yet (fresh signup that still needs onboarding).
 */
export async function getCurrentUser(
  supabase: ServerClient
): Promise<CurrentUser | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: profile } = await supabase
    .from("profiles")
    .select("*, companies(*)")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile || !profile.companies) return null;

  const { companies: company, ...profileRow } = profile;
  return {
    userId: user.id,
    email: user.email ?? null,
    profile: profileRow,
    company,
  };
}

/** Overview grid rows, optionally filtered to one status. */
export async function getProjectOverviews(
  supabase: ServerClient,
  status?: ProjectStatus
): Promise<ProjectOverview[]> {
  let query = supabase
    .from("project_overview")
    .select("*")
    .order("last_activity_at", { ascending: false });
  if (status) query = query.eq("status", status);
  const { data } = await query;
  return data ?? [];
}

export type TaskWithAssignees = Task & {
  task_assignments: { profile_id: string; profiles: Pick<Profile, "id" | "full_name" | "role"> }[];
};

export async function getProjectTasks(
  supabase: ServerClient,
  projectId: string
): Promise<TaskWithAssignees[]> {
  const { data } = await supabase
    .from("tasks")
    .select(
      "*, task_assignments(profile_id, profiles!task_assignments_profile_id_fkey(id, full_name, role))"
    )
    .eq("project_id", projectId)
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });
  return (data as TaskWithAssignees[] | null) ?? [];
}

export type ProjectMemberWithProfile = {
  project_id: string;
  profile_id: string;
  profiles: Pick<Profile, "id" | "full_name" | "role" | "phone">;
};

export async function getProjectMembers(
  supabase: ServerClient,
  projectId: string
): Promise<ProjectMemberWithProfile[]> {
  const { data } = await supabase
    .from("project_members")
    .select(
      "project_id, profile_id, profiles!project_members_profile_id_fkey(id, full_name, role, phone)"
    )
    .eq("project_id", projectId);
  return (data as ProjectMemberWithProfile[] | null) ?? [];
}

export async function getCompanyMembers(
  supabase: ServerClient
): Promise<Profile[]> {
  const { data } = await supabase
    .from("profiles")
    .select("*")
    .order("full_name", { ascending: true });
  return data ?? [];
}

export type OpenInvite = Invite & {
  invited_by_profile: Pick<Profile, "full_name"> | null;
};

export async function getOpenInvites(
  supabase: ServerClient
): Promise<OpenInvite[]> {
  const { data } = await supabase
    .from("invites")
    .select("*, invited_by_profile:profiles!invites_invited_by_fkey(full_name)")
    .is("redeemed_at", null)
    .order("created_at", { ascending: false });
  return (data as OpenInvite[] | null) ?? [];
}
