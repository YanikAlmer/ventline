import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import {
  PhotoTimeline,
  type TimelinePhoto,
} from "@/components/portal/photo-timeline";
import { ProjectStatusPill } from "@/components/status-pill";
import { getLocale, getTranslator } from "@/i18n/server";
import type { Tables } from "@/lib/database.types";
import { formatDate } from "@/lib/format";
import { signedUrlMap } from "@/lib/storage";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("portal.project.title") };
}

type SharedPhotoMessage = Tables<"messages"> & {
  sender: Pick<Tables<"profiles">, "full_name"> | null;
  attachments: (Tables<"attachments"> & {
    photo_annotations: Pick<
      Tables<"photo_annotations">,
      "rendered_path" | "created_at"
    >[];
  })[];
};

export default async function PortalProjectPage(props: {
  params: Promise<{ projectId: string }>;
}) {
  const { projectId } = await props.params;
  const supabase = await createClient();
  const t = await getTranslator();
  const locale = await getLocale();

  const { data: project } = await supabase
    .from("projects")
    .select("*")
    .eq("id", projectId)
    .maybeSingle();
  if (!project) notFound();

  const [tasksResult, messagesResult] = await Promise.all([
    supabase
      .from("tasks")
      .select("*")
      .eq("project_id", projectId)
      .order("created_at", { ascending: true }),
    supabase
      .from("messages")
      .select(
        "*, sender:profiles!messages_sender_id_fkey(full_name), attachments!inner(*, photo_annotations(rendered_path, created_at))"
      )
      .eq("project_id", projectId)
      .eq("attachments.kind", "photo")
      .order("created_at", { ascending: false })
      .limit(200),
  ]);

  const tasks = tasksResult.data ?? [];
  const messages =
    (messagesResult.data as unknown as SharedPhotoMessage[] | null) ?? [];

  // Newest annotation render replaces the raw photo.
  const photoEntries = messages.flatMap((message) =>
    message.attachments
      .filter((att) => att.kind === "photo")
      .map((att) => {
        const newest = [...att.photo_annotations].sort((a, b) =>
          b.created_at.localeCompare(a.created_at)
        )[0];
        return {
          id: att.id,
          path: newest?.rendered_path ?? att.storage_path,
          annotated: Boolean(newest),
          caption: message.body,
          senderName: message.sender?.full_name ?? null,
          createdAt: message.created_at,
        };
      })
  );

  const urlMap = await signedUrlMap(
    supabase,
    "photos",
    photoEntries.map((p) => p.path)
  );

  const photos: TimelinePhoto[] = photoEntries.flatMap((entry) => {
    const url = urlMap.get(entry.path);
    return url ? [{ ...entry, url }] : [];
  });

  return (
    <div>
      <nav className="mb-4 text-sm text-slate-500">
        <Link href="/portal" className="font-semibold hover:text-slate-900">
          {t("portal.home.title")}
        </Link>{" "}
        / <span className="text-slate-700">{project.name}</span>
      </nav>

      <div className="mb-6 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-slate-900">
            {project.name}
          </h1>
          {project.address && (
            <p className="mt-0.5 text-sm text-slate-500">{project.address}</p>
          )}
        </div>
        <ProjectStatusPill status={project.status} />
      </div>

      {tasks.length > 0 && (
        <section className="mb-8 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <h2 className="mb-3 text-lg font-bold text-slate-900">
            {t("portal.project.progress")}
          </h2>
          <ul className="space-y-2.5">
            {tasks.map((task) => {
              const checked =
                task.status === "done" || task.status === "approved";
              return (
                <li key={task.id} className="flex items-start gap-3">
                  <span
                    aria-hidden
                    className={`mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full text-[11px] font-black ${
                      checked
                        ? "bg-emerald-500 text-white"
                        : "border-2 border-slate-300 bg-white"
                    }`}
                  >
                    {checked ? "✓" : ""}
                  </span>
                  <div className="min-w-0">
                    <p
                      className={`text-sm font-semibold ${
                        checked
                          ? "text-slate-400 line-through"
                          : "text-slate-800"
                      }`}
                    >
                      {task.title}
                    </p>
                    {task.due_date && !checked && (
                      <p className="text-xs text-slate-400">
                        {t("portal.project.plannedFor", {
                          date: formatDate(task.due_date, locale),
                        })}
                      </p>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        </section>
      )}

      <section>
        <h2 className="mb-3 text-lg font-bold text-slate-900">
          {t("portal.project.photoUpdates")}
        </h2>
        {photos.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center text-sm text-slate-500">
            {t("portal.project.noPhotos")}
          </div>
        ) : (
          <PhotoTimeline photos={photos} />
        )}
      </section>
    </div>
  );
}
