import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { ChatThread } from "@/components/chat/chat-thread";
import { getTranslator } from "@/i18n/server";
import { getCurrentUser } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("chat.title") };
}

export default async function ProjectChatPage(props: {
  params: Promise<{ projectId: string }>;
}) {
  const { projectId } = await props.params;
  const t = await getTranslator();
  const supabase = await createClient();

  const [current, projectResult] = await Promise.all([
    getCurrentUser(supabase),
    supabase
      .from("projects")
      .select("id, name, company_id")
      .eq("id", projectId)
      .maybeSingle(),
  ]);
  if (!current) return null;
  const project = projectResult.data;
  if (!project) notFound();

  return (
    <div className="mx-auto flex min-h-[calc(100dvh-56px)] max-w-4xl flex-col px-4 py-6 sm:px-6 md:min-h-dvh">
      <nav className="mb-4 text-sm text-slate-500">
        <Link href="/" className="font-semibold hover:text-slate-900">
          {t("nav.projects")}
        </Link>{" "}
        /{" "}
        <Link
          href={`/projects/${project.id}`}
          className="font-semibold hover:text-slate-900"
        >
          {project.name}
        </Link>{" "}
        / <span className="text-slate-700">{t("chat.breadcrumb")}</span>
      </nav>

      <h1 className="mb-4 text-xl font-black tracking-tight text-slate-900">
        {t("chat.title")}
      </h1>

      <ChatThread
        companyId={project.company_id}
        projectId={project.id}
        taskId={null}
        currentUserId={current.userId}
        role={current.profile.role}
      />
    </div>
  );
}
