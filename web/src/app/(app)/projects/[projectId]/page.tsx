import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { MembersPanel } from "@/components/project/members-panel";
import { NewTaskButton } from "@/components/project/new-task-button";
import { ProjectStatusSelect } from "@/components/project/project-status-select";
import { TaskStatusPill } from "@/components/status-pill";
import { Avatar } from "@/components/avatar";
import { getLocale, getTranslator } from "@/i18n/server";
import { formatDate } from "@/lib/format";
import {
  getCompanyMembers,
  getCurrentUser,
  getProjectMembers,
  getProjectTasks,
} from "@/lib/queries";
import { TASK_STATUSES, isOffice } from "@/lib/status";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("projects.detail.metaTitle") };
}

export default async function ProjectPage(props: {
  params: Promise<{ projectId: string }>;
}) {
  const { projectId } = await props.params;
  const t = await getTranslator();
  const locale = await getLocale();
  const supabase = await createClient();

  const [current, projectResult] = await Promise.all([
    getCurrentUser(supabase),
    supabase.from("projects").select("*").eq("id", projectId).maybeSingle(),
  ]);
  if (!current) return null;
  const project = projectResult.data;
  if (!project) notFound();

  const canManageProject =
    isOffice(current.profile.role) || current.profile.role === "foreman";

  const [tasks, members, companyMembers] = await Promise.all([
    getProjectTasks(supabase, projectId),
    getProjectMembers(supabase, projectId),
    canManageProject ? getCompanyMembers(supabase) : Promise.resolve([]),
  ]);

  const grouped = TASK_STATUSES.map((status) => ({
    status,
    tasks: tasks.filter((task) => task.status === status),
  }));

  const assignableMembers = members
    .map((m) => m.profiles)
    .filter((p) => p.role !== "customer");

  return (
    <div className="mx-auto max-w-6xl px-4 py-6 sm:px-6">
      <nav className="mb-4 text-sm text-slate-500">
        <Link href="/" className="font-semibold hover:text-slate-900">
          {t("nav.projects")}
        </Link>{" "}
        / <span className="text-slate-700">{project.name}</span>
      </nav>

      <div className="mb-6 flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0">
          <h1 className="text-2xl font-black tracking-tight text-slate-900">
            {project.name}
          </h1>
          {project.address && (
            <p className="mt-0.5 text-sm text-slate-500">{project.address}</p>
          )}
          {project.description && (
            <p className="mt-2 max-w-2xl text-sm text-slate-600">
              {project.description}
            </p>
          )}
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <ProjectStatusSelect
            projectId={project.id}
            status={project.status}
            editable={canManageProject}
          />
          <Link
            href={`/projects/${project.id}/chat`}
            className="inline-flex min-h-11 items-center gap-2 rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50"
          >
            💬 {t("projects.detail.chat")}
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_300px]">
        <section>
          <div className="mb-4 flex items-center justify-between gap-3">
            <h2 className="text-lg font-bold text-slate-900">
              {t("projects.detail.tasks")}{" "}
              <span className="text-sm font-semibold text-slate-400">
                {tasks.length}
              </span>
            </h2>
            <NewTaskButton
              projectId={project.id}
              companyId={project.company_id}
              members={assignableMembers}
            />
          </div>

          {tasks.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center text-sm text-slate-500">
              {t("projects.detail.noTasks")}
            </div>
          ) : (
            <div className="space-y-5">
              {grouped.map(({ status, tasks: group }) =>
                group.length === 0 ? null : (
                  <div key={status}>
                    <h3 className="mb-2 flex items-center gap-2 text-sm font-bold uppercase tracking-wide text-slate-500">
                      {t(`status.task.${status}`)}
                      <span className="rounded-full bg-slate-200 px-2 py-0.5 text-xs font-bold text-slate-600">
                        {group.length}
                      </span>
                    </h3>
                    <ul className="space-y-2">
                      {group.map((task) => (
                        <li key={task.id}>
                          <Link
                            href={`/projects/${project.id}/tasks/${task.id}`}
                            className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 shadow-sm transition-shadow hover:shadow-md"
                          >
                            <div className="min-w-0 flex-1">
                              <p className="truncate font-semibold text-slate-900">
                                {task.title}
                              </p>
                              <p className="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-slate-500">
                                {task.due_date && (
                                  <span>
                                    {t("projects.detail.due", {
                                      date: formatDate(task.due_date, locale),
                                    })}
                                  </span>
                                )}
                                {task.visible_to_customer && (
                                  <span className="font-semibold text-rose-600">
                                    {t("projects.detail.customerVisible")}
                                  </span>
                                )}
                              </p>
                            </div>
                            <div className="flex items-center -space-x-1.5">
                              {task.task_assignments.slice(0, 3).map((a) => (
                                <Avatar
                                  key={a.profile_id}
                                  name={a.profiles.full_name}
                                  seed={a.profiles.id}
                                  size="sm"
                                />
                              ))}
                            </div>
                            <TaskStatusPill status={task.status} />
                          </Link>
                        </li>
                      ))}
                    </ul>
                  </div>
                )
              )}
            </div>
          )}
        </section>

        <MembersPanel
          projectId={project.id}
          members={members}
          companyMembers={companyMembers}
          role={current.profile.role}
          currentUserId={current.userId}
        />
      </div>
    </div>
  );
}
