import type { Metadata } from "next";
import Link from "next/link";

import { NewProjectButton } from "@/components/overview/new-project-button";
import { ProjectCard } from "@/components/overview/project-card";
import { getCurrentUser, getProjectOverviews } from "@/lib/queries";
import {
  PROJECT_STATUSES,
  PROJECT_STATUS_LABELS,
  isOffice,
  type ProjectStatus,
} from "@/lib/status";
import { signedUrlMap } from "@/lib/storage";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Overview" };

function parseStatus(value: string | undefined): ProjectStatus | undefined {
  return PROJECT_STATUSES.find((s) => s === value);
}

export default async function OverviewPage(props: {
  searchParams: Promise<{ status?: string }>;
}) {
  const searchParams = await props.searchParams;
  const statusFilter = parseStatus(searchParams.status);

  const supabase = await createClient();
  const [current, projects] = await Promise.all([
    getCurrentUser(supabase),
    getProjectOverviews(supabase, statusFilter),
  ]);
  if (!current) return null; // layout redirects

  const thumbs = await signedUrlMap(
    supabase,
    "photos",
    projects.flatMap((p) => (p.latest_photo_path ? [p.latest_photo_path] : []))
  );

  const tabs: { label: string; value: ProjectStatus | null }[] = [
    { label: "All", value: null },
    ...PROJECT_STATUSES.map((s) => ({
      label: PROJECT_STATUS_LABELS[s],
      value: s,
    })),
  ];

  return (
    <div className="mx-auto max-w-6xl px-4 py-6 sm:px-6">
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-slate-900">
            Projects
          </h1>
          <p className="text-sm text-slate-500">{current.company.name}</p>
        </div>
        {isOffice(current.profile.role) && <NewProjectButton />}
      </div>

      <div className="mb-6 flex gap-1.5 overflow-x-auto pb-1">
        {tabs.map((tab) => {
          const active = tab.value === (statusFilter ?? null);
          return (
            <Link
              key={tab.label}
              href={tab.value ? `/?status=${tab.value}` : "/"}
              className={`whitespace-nowrap rounded-full px-3.5 py-2 text-sm font-semibold transition-colors ${
                active
                  ? "bg-slate-900 text-white"
                  : "bg-white text-slate-600 ring-1 ring-inset ring-slate-200 hover:bg-slate-50"
              }`}
            >
              {tab.label}
            </Link>
          );
        })}
      </div>

      {projects.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center">
          <p className="font-semibold text-slate-700">No projects here yet</p>
          <p className="mt-1 text-sm text-slate-500">
            {statusFilter
              ? `No ${PROJECT_STATUS_LABELS[statusFilter].toLowerCase()} projects.`
              : isOffice(current.profile.role)
                ? "Create your first project to get started."
                : "You will see projects here once you are added to one."}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {projects.map((project) =>
            project.id ? (
              <ProjectCard
                key={project.id}
                project={project}
                thumbnailUrl={
                  project.latest_photo_path
                    ? (thumbs.get(project.latest_photo_path) ?? null)
                    : null
                }
              />
            ) : null
          )}
        </div>
      )}
    </div>
  );
}
