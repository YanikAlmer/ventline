import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { Avatar } from "@/components/avatar";
import { ChatThread } from "@/components/chat/chat-thread";
import { CustomerVisibilityToggle } from "@/components/task/customer-visibility-toggle";
import { TaskStatusControl } from "@/components/task/task-status-control";
import { getLocale, getTranslator } from "@/i18n/server";
import { formatDate } from "@/lib/format";
import { getCurrentUser } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("tasks.detail.metaTitle") };
}

export default async function TaskPage(props: {
  params: Promise<{ projectId: string; taskId: string }>;
}) {
  const { projectId, taskId } = await props.params;
  const supabase = await createClient();
  const t = await getTranslator();
  const locale = await getLocale();

  const [current, taskResult] = await Promise.all([
    getCurrentUser(supabase),
    supabase
      .from("tasks")
      .select(
        "*, projects(id, name), task_assignments(profile_id, profiles!task_assignments_profile_id_fkey(id, full_name, role))"
      )
      .eq("id", taskId)
      .eq("project_id", projectId)
      .maybeSingle(),
  ]);
  if (!current) return null;
  const task = taskResult.data;
  if (!task || !task.projects) notFound();

  const isAssigned = task.task_assignments.some(
    (a) => a.profile_id === current.userId
  );
  const isWorker = current.profile.role === "worker";

  return (
    <div className="mx-auto flex min-h-[calc(100dvh-56px)] max-w-4xl flex-col px-4 py-6 sm:px-6 md:min-h-dvh">
      <nav className="mb-4 text-sm text-slate-500">
        <Link href="/" className="font-semibold hover:text-slate-900">
          {t("nav.projects")}
        </Link>{" "}
        /{" "}
        <Link
          href={`/projects/${projectId}`}
          className="font-semibold hover:text-slate-900"
        >
          {task.projects.name}
        </Link>{" "}
        / <span className="text-slate-700">{task.title}</span>
      </nav>

      <div className="mb-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <h1 className="text-xl font-black tracking-tight text-slate-900">
              {task.title}
            </h1>
            {task.description && (
              <p className="mt-1.5 max-w-2xl whitespace-pre-wrap text-sm text-slate-600">
                {task.description}
              </p>
            )}
          </div>
          <TaskStatusControl
            taskId={task.id}
            projectId={projectId}
            status={task.status}
            role={current.profile.role}
            isAssigned={isAssigned}
          />
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-x-6 gap-y-3 border-t border-slate-100 pt-4">
          <div className="text-sm">
            <span className="font-semibold text-slate-500">
              {t("tasks.detail.dueLabel")}{" "}
            </span>
            <span className="font-semibold text-slate-900">
              {formatDate(task.due_date, locale)}
            </span>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-slate-500">
              {t("tasks.detail.assignedLabel")}
            </span>
            {task.task_assignments.length === 0 ? (
              <span className="text-sm text-slate-400">
                {t("tasks.detail.noAssignees")}
              </span>
            ) : (
              <span className="flex items-center gap-1.5">
                {task.task_assignments.map((a) => (
                  <span
                    key={a.profile_id}
                    className="inline-flex items-center gap-1.5 rounded-full bg-slate-100 py-1 pl-1 pr-2.5 text-xs font-semibold text-slate-700"
                  >
                    <Avatar
                      name={a.profiles.full_name}
                      seed={a.profiles.id}
                      size="sm"
                    />
                    {a.profiles.full_name}
                  </span>
                ))}
              </span>
            )}
          </div>

          {!isWorker && (
            <CustomerVisibilityToggle
              taskId={task.id}
              visible={task.visible_to_customer}
            />
          )}
          {isWorker && task.visible_to_customer && (
            <span className="text-xs font-semibold text-rose-600">
              {t("tasks.detail.customerVisible")}
            </span>
          )}
        </div>
      </div>

      <ChatThread
        companyId={task.company_id}
        projectId={projectId}
        taskId={task.id}
        currentUserId={current.userId}
        role={current.profile.role}
      />
    </div>
  );
}
