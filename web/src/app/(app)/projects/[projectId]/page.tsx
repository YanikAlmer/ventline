import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { MembersPanel } from "@/components/project/members-panel";
import { NewTaskButton } from "@/components/project/new-task-button";
import { ProjectStatusSelect } from "@/components/project/project-status-select";
import { TaskBoard } from "@/components/project/task-board";
import { getLocale, getTranslator } from "@/i18n/server";
import {
  getCompanyMembers,
  getCurrentUser,
  getProjectMembers,
  getProjectTasks,
  groupIntoPackages,
} from "@/lib/queries";
import { isOffice } from "@/lib/status";
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

  const packages = groupIntoPackages(tasks);

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
                {packages.length}
              </span>
            </h2>
            <NewTaskButton
              projectId={project.id}
              companyId={project.company_id}
              members={assignableMembers}
            />
          </div>

          <TaskBoard
            projectId={project.id}
            companyId={project.company_id}
            packages={packages}
            members={assignableMembers}
            locale={locale}
            canManage={canManageProject}
          />
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
