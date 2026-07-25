import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { Avatar } from "@/components/avatar";
import { ChatThread } from "@/components/chat/chat-thread";
import { formatDueMoment } from "@/components/project/task-board";
import { TaskStatusPill } from "@/components/status-pill";
import { CustomerVisibilityToggle } from "@/components/task/customer-visibility-toggle";
import { TaskFiles } from "@/components/task/task-files";
import { TaskStatusControl } from "@/components/task/task-status-control";
import { getLocale, getTranslator } from "@/i18n/server";
import { getCurrentUser, getTaskAttachments } from "@/lib/queries";
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

  // The package this task belongs to, and the steps underneath it — a task is
  // one or the other, never both, so only one of these ever returns rows.
  //
  // The parent is fetched separately rather than embedded: the generated types
  // describe a self-referential embed as an array, while PostgREST actually
  // returns a single object for a to-one FK. Rather than cast around that
  // mismatch, ask for the row directly.
  const [parentResult, stepsResult, attachments] = await Promise.all([
    task.parent_id
      ? supabase
          .from("tasks")
          .select("id, title, visible_to_customer")
          .eq("id", task.parent_id)
          .maybeSingle()
      : Promise.resolve({ data: null }),
    supabase
      .from("tasks")
      .select("id, title, status, due_date, due_time")
      .eq("parent_id", task.id)
      .order("sort_order", { ascending: true })
      .order("created_at", { ascending: true }),
    getTaskAttachments(supabase, task.id),
  ]);
  const parent = parentResult.data;
  const steps = stepsResult.data;

  const isAssigned = task.task_assignments.some(
    (a) => a.profile_id === current.userId
  );
  const isWorker = current.profile.role === "worker";
  const isCustomer = current.profile.role === "customer";
  // A step marked customer-visible inside a hidden package is not actually
  // visible; say so rather than letting the toggle imply otherwise.
  const hiddenByPackage =
    task.visible_to_customer && parent !== null && !parent.visible_to_customer;

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
        /{" "}
        {parent && (
          <>
            <Link
              href={`/projects/${projectId}/tasks/${parent.id}`}
              className="font-semibold hover:text-slate-900"
            >
              {parent.title}
            </Link>{" "}
            /{" "}
          </>
        )}
        <span className="text-slate-700">{task.title}</span>
      </nav>

      <div className="mb-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-xs font-bold uppercase tracking-wide text-slate-400">
              {parent ? t("tasks.step.label") : t("tasks.package.label")}
            </p>
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
              {task.due_date
                ? formatDueMoment(task.due_date, task.due_time, locale)
                : "—"}
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

        {hiddenByPackage && (
          <p className="mt-3 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
            {t("tasks.detail.hiddenByPackage", {
              package: parent?.title ?? "",
            })}
          </p>
        )}

        {steps && steps.length > 0 && (
          <div className="mt-4 border-t border-slate-100 pt-4">
            <h2 className="mb-2 text-sm font-bold uppercase tracking-wide text-slate-500">
              {t("tasks.detail.stepsLabel")}{" "}
              <span className="text-slate-400">
                {t("tasks.steps.progress", {
                  done: steps.filter(
                    (s) => s.status === "done" || s.status === "approved"
                  ).length,
                  total: steps.length,
                })}
              </span>
            </h2>
            <ul className="divide-y divide-slate-100">
              {steps.map((step) => (
                <li key={step.id}>
                  <Link
                    href={`/projects/${projectId}/tasks/${step.id}`}
                    className="flex items-center gap-3 py-2.5 transition-colors hover:bg-slate-50"
                  >
                    <span className="min-w-0 flex-1 truncate text-sm text-slate-800">
                      {step.title}
                    </span>
                    {step.due_date && (
                      <span className="shrink-0 text-xs text-slate-500">
                        {formatDueMoment(step.due_date, step.due_time, locale)}
                      </span>
                    )}
                    <TaskStatusPill status={step.status} />
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>

      <TaskFiles
        taskId={task.id}
        companyId={task.company_id}
        projectId={projectId}
        initial={attachments}
        currentUserId={current.userId}
        canEdit={!isCustomer}
      />

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
