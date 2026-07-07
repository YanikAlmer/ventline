import type { Database } from "@/lib/database.types";

export type ProjectStatus = Database["public"]["Enums"]["project_status"];
export type TaskStatus = Database["public"]["Enums"]["task_status"];
export type AppRole = Database["public"]["Enums"]["app_role"];

export const PROJECT_STATUSES: ProjectStatus[] = [
  "planning",
  "active",
  "on_hold",
  "completed",
  "archived",
];

export const TASK_STATUSES: TaskStatus[] = [
  "todo",
  "in_progress",
  "blocked",
  "done",
  "approved",
];

export const PROJECT_STATUS_LABELS: Record<ProjectStatus, string> = {
  planning: "Planning",
  active: "Active",
  on_hold: "On hold",
  completed: "Completed",
  archived: "Archived",
};

export const TASK_STATUS_LABELS: Record<TaskStatus, string> = {
  todo: "To do",
  in_progress: "In progress",
  blocked: "Blocked",
  done: "Done",
  approved: "Approved",
};

export const PROJECT_STATUS_PILL: Record<ProjectStatus, string> = {
  planning: "bg-slate-100 text-slate-700 ring-slate-600/20",
  active: "bg-emerald-100 text-emerald-800 ring-emerald-600/20",
  on_hold: "bg-amber-100 text-amber-800 ring-amber-600/20",
  completed: "bg-blue-100 text-blue-800 ring-blue-600/20",
  archived: "bg-gray-100 text-gray-600 ring-gray-500/20",
};

export const TASK_STATUS_PILL: Record<TaskStatus, string> = {
  todo: "bg-slate-100 text-slate-700 ring-slate-600/20",
  in_progress: "bg-sky-100 text-sky-800 ring-sky-600/20",
  blocked: "bg-red-100 text-red-800 ring-red-600/20",
  done: "bg-amber-100 text-amber-800 ring-amber-600/20",
  approved: "bg-emerald-100 text-emerald-800 ring-emerald-600/20",
};

export const TASK_STATUS_DOT: Record<TaskStatus, string> = {
  todo: "bg-slate-400",
  in_progress: "bg-sky-500",
  blocked: "bg-red-500",
  done: "bg-amber-500",
  approved: "bg-emerald-500",
};

export const ROLE_LABELS: Record<AppRole, string> = {
  owner: "Owner",
  manager: "Manager",
  foreman: "Foreman",
  worker: "Worker",
  customer: "Customer",
};

export const ROLE_BADGE: Record<AppRole, string> = {
  owner: "bg-violet-100 text-violet-800 ring-violet-600/20",
  manager: "bg-indigo-100 text-indigo-800 ring-indigo-600/20",
  foreman: "bg-cyan-100 text-cyan-800 ring-cyan-600/20",
  worker: "bg-slate-100 text-slate-700 ring-slate-600/20",
  customer: "bg-rose-100 text-rose-800 ring-rose-600/20",
};

/** Owner or manager — the "office" roles with company-wide visibility. */
export function isOffice(role: AppRole): boolean {
  return role === "owner" || role === "manager";
}

/** Statuses this role may move a task to (given they may edit it at all). */
export function allowedTaskStatuses(role: AppRole): TaskStatus[] {
  if (role === "worker") return ["todo", "in_progress", "blocked", "done"];
  if (role === "customer") return [];
  return TASK_STATUSES;
}
