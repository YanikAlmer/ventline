"use client";

import { useTranslator } from "@/i18n/client";
import {
  PROJECT_STATUS_PILL,
  ROLE_BADGE,
  TASK_STATUS_PILL,
  projectStatusLabel,
  roleLabel,
  taskStatusLabel,
  type AppRole,
  type ProjectStatus,
  type TaskStatus,
} from "@/lib/status";

const PILL_BASE =
  "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ring-1 ring-inset whitespace-nowrap";

export function ProjectStatusPill({ status }: { status: ProjectStatus }) {
  const t = useTranslator();
  return (
    <span className={`${PILL_BASE} ${PROJECT_STATUS_PILL[status]}`}>
      {projectStatusLabel(t, status)}
    </span>
  );
}

export function TaskStatusPill({ status }: { status: TaskStatus }) {
  const t = useTranslator();
  return (
    <span className={`${PILL_BASE} ${TASK_STATUS_PILL[status]}`}>
      {taskStatusLabel(t, status)}
    </span>
  );
}

export function RoleBadge({ role }: { role: AppRole }) {
  const t = useTranslator();
  return (
    <span className={`${PILL_BASE} ${ROLE_BADGE[role]}`}>
      {roleLabel(t, role)}
    </span>
  );
}
