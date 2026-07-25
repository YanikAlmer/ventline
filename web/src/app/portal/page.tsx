import type { Metadata } from "next";
import Link from "next/link";

import { ProjectStatusPill } from "@/components/status-pill";
import { getTranslator } from "@/i18n/server";
import { getCurrentUser, getProjectOverviews } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("portal.home.title") };
}

export default async function PortalHomePage() {
  const supabase = await createClient();
  const [t, current, projects] = await Promise.all([
    getTranslator(),
    getCurrentUser(supabase),
    getProjectOverviews(supabase),
  ]);
  if (!current) return null;

  return (
    <div>
      <h1 className="mb-1 text-2xl font-black tracking-tight text-slate-900">
        {t("portal.home.welcome", {
          name: current.profile.full_name.split(" ")[0],
        })}
      </h1>
      <p className="mb-6 text-sm text-slate-500">
        {t("portal.home.subtitle")}
      </p>

      {projects.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center text-sm text-slate-500">
          {t("portal.home.empty", { company: current.company.name })}
        </div>
      ) : (
        <ul className="space-y-3">
          {projects.map((project) => {
            const total = project.task_count ?? 0;
            const finished =
              (project.done_count ?? 0) + (project.approved_count ?? 0);
            const pct = total > 0 ? Math.round((finished / total) * 100) : 0;
            return (
              <li key={project.id}>
                <Link
                  href={`/portal/${project.id}`}
                  className="block rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition-shadow hover:shadow-md"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <h2 className="font-bold text-slate-900">
                        {project.name}
                      </h2>
                      {project.address && (
                        <p className="mt-0.5 text-sm text-slate-500">
                          {project.address}
                        </p>
                      )}
                    </div>
                    {project.status && (
                      <ProjectStatusPill status={project.status} />
                    )}
                  </div>
                  {total > 0 && (
                    <div className="mt-4">
                      <div className="mb-1 flex justify-between text-xs font-semibold text-slate-500">
                        <span>
                          {t("portal.home.stepsFinished", {
                            count: total,
                            finished,
                            total,
                          })}
                        </span>
                        <span>{pct}%</span>
                      </div>
                      <div className="h-2.5 overflow-hidden rounded-full bg-slate-100">
                        <div
                          className="h-full rounded-full bg-emerald-500"
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  )}
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
