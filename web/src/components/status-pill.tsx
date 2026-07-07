import {
  PROJECT_STATUS_LABELS,
  PROJECT_STATUS_PILL,
  ROLE_BADGE,
  ROLE_LABELS,
  TASK_STATUS_LABELS,
  TASK_STATUS_PILL,
  type AppRole,
  type ProjectStatus,
  type TaskStatus,
} from "@/lib/status";

const PILL_BASE =
  "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ring-1 ring-inset whitespace-nowrap";

export function ProjectStatusPill({ status }: { status: ProjectStatus }) {
  return (
    <span className={`${PILL_BASE} ${PROJECT_STATUS_PILL[status]}`}>
      {PROJECT_STATUS_LABELS[status]}
    </span>
  );
}

export function TaskStatusPill({ status }: { status: TaskStatus }) {
  return (
    <span className={`${PILL_BASE} ${TASK_STATUS_PILL[status]}`}>
      {TASK_STATUS_LABELS[status]}
    </span>
  );
}

export function RoleBadge({ role }: { role: AppRole }) {
  return (
    <span className={`${PILL_BASE} ${ROLE_BADGE[role]}`}>
      {ROLE_LABELS[role]}
    </span>
  );
}
