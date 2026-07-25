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

  const { data: profile, error } = await supabase
    .from("profiles")
    .select("*, companies(*)")
    .eq("id", user.id)
    .maybeSingle();
  // A genuine read failure (DB/network error, RLS misconfig) must NOT be
  // conflated with "no profile yet": returning null there would eject a
  // fully-onboarded user into the onboarding flow. Surface it instead so the
  // caller renders an error boundary rather than a misleading redirect.
  if (error) {
    throw new Error(`Failed to load your profile: ${error.message}`);
  }
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

/**
 * A work package (Arbeitspaket) with its steps (Arbeitsschritte) attached.
 * The board renders packages only; steps live inside their parent.
 */
export type WorkPackage = TaskWithAssignees & { steps: TaskWithAssignees[] };

/**
 * Split a flat task list into the two-level tree.
 *
 * A step whose package is missing from the list is promoted to the top level
 * rather than dropped. That should be impossible — the visibility rule makes a
 * step readable only when its package is — but a task silently vanishing from
 * a board is a far worse failure than one shown at the wrong indent.
 */
export function groupIntoPackages(tasks: TaskWithAssignees[]): WorkPackage[] {
  const byId = new Map(tasks.map((task) => [task.id, task]));
  const packages = new Map<string, WorkPackage>();

  for (const task of tasks) {
    if (task.parent_id === null || !byId.has(task.parent_id)) {
      packages.set(task.id, { ...task, steps: [] });
    }
  }
  for (const task of tasks) {
    if (task.parent_id === null) continue;
    packages.get(task.parent_id)?.steps.push(task);
  }
  return [...packages.values()];
}

/** Steps that count as finished, for the "4/7 Schritte" progress chip. */
export function stepProgress(pkg: WorkPackage): { done: number; total: number } {
  return {
    done: pkg.steps.filter(
      (step) => step.status === "done" || step.status === "approved"
    ).length,
    total: pkg.steps.length,
  };
}

export type TaskAttachment = Tables<"attachments">;

export async function getTaskAttachments(
  supabase: ServerClient,
  taskId: string
): Promise<TaskAttachment[]> {
  const { data } = await supabase
    .from("attachments")
    .select("*")
    .eq("task_id", taskId)
    .order("created_at", { ascending: true });
  return data ?? [];
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
