/* eslint-disable @next/next/no-img-element -- signed Supabase URLs are
   short-lived and remote-pattern config for next/image would break on
   per-project domains; plain img is the right tool here. */
import Link from "next/link";

import { ProjectStatusPill } from "@/components/status-pill";
import { relativeTime } from "@/lib/format";
import type { ProjectOverview } from "@/lib/queries";
import { TASK_STATUS_DOT, TASK_STATUS_LABELS } from "@/lib/status";

export function ProjectCard({
  project,
  thumbnailUrl,
}: {
  project: ProjectOverview;
  thumbnailUrl: string | null;
}) {
  const total = project.task_count ?? 0;
  const finished = (project.done_count ?? 0) + (project.approved_count ?? 0);
  const pct = total > 0 ? Math.round((finished / total) * 100) : 0;

  const counts = [
    { label: TASK_STATUS_LABELS.todo, dot: TASK_STATUS_DOT.todo, value: project.todo_count ?? 0 },
    { label: TASK_STATUS_LABELS.in_progress, dot: TASK_STATUS_DOT.in_progress, value: project.in_progress_count ?? 0 },
    { label: TASK_STATUS_LABELS.blocked, dot: TASK_STATUS_DOT.blocked, value: project.blocked_count ?? 0 },
    { label: TASK_STATUS_LABELS.done, dot: TASK_STATUS_DOT.done, value: project.done_count ?? 0 },
    { label: TASK_STATUS_LABELS.approved, dot: TASK_STATUS_DOT.approved, value: project.approved_count ?? 0 },
  ];

  return (
    <Link
      href={`/projects/${project.id}`}
      className="group flex flex-col overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm transition-shadow hover:shadow-md"
    >
      <div className="relative h-32 bg-slate-100">
        {thumbnailUrl ? (
          <img
            src={thumbnailUrl}
            alt=""
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full items-center justify-center text-3xl text-slate-300">
            🏗
          </div>
        )}
        <div className="absolute right-3 top-3">
          {project.status && <ProjectStatusPill status={project.status} />}
        </div>
      </div>

      <div className="flex flex-1 flex-col gap-3 p-4">
        <div>
          <h2 className="font-bold text-slate-900 group-hover:underline">
            {project.name}
          </h2>
          {project.address && (
            <p className="mt-0.5 truncate text-sm text-slate-500">
              {project.address}
            </p>
          )}
        </div>

        <div>
          <div className="mb-1 flex items-center justify-between text-xs font-semibold text-slate-500">
            <span>
              {finished}/{total} tasks finished
            </span>
            <span>{pct}%</span>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-slate-100">
            <div
              className="h-full rounded-full bg-emerald-500 transition-all"
              style={{ width: `${pct}%` }}
            />
          </div>
        </div>

        <div className="flex flex-wrap gap-x-3 gap-y-1">
          {counts.map((c) => (
            <span
              key={c.label}
              className="inline-flex items-center gap-1.5 text-xs text-slate-600"
              title={c.label}
            >
              <span className={`size-2 rounded-full ${c.dot}`} />
              {c.value}
            </span>
          ))}
        </div>

        <div className="mt-auto flex items-center justify-between border-t border-slate-100 pt-3 text-xs text-slate-500">
          <span>Active {relativeTime(project.last_activity_at)}</span>
          <span>
            {project.member_count ?? 0}{" "}
            {(project.member_count ?? 0) === 1 ? "member" : "members"}
          </span>
        </div>
      </div>
    </Link>
  );
}
