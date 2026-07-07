import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { ChatThread } from "@/components/chat/chat-thread";
import { getCurrentUser } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Project chat" };

export default async function ProjectChatPage(props: {
  params: Promise<{ projectId: string }>;
}) {
  const { projectId } = await props.params;
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
          Projects
        </Link>{" "}
        /{" "}
        <Link
          href={`/projects/${project.id}`}
          className="font-semibold hover:text-slate-900"
        >
          {project.name}
        </Link>{" "}
        / <span className="text-slate-700">Chat</span>
      </nav>

      <h1 className="mb-4 text-xl font-black tracking-tight text-slate-900">
        Project chat
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
