import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { InboxView } from "@/components/inbox/inbox-view";
import { getTranslator } from "@/i18n/server";
import { getAttention, getInboxThreads } from "@/lib/inbox";
import { getCompanyMembers, getCurrentUser, getProjectOverviews } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("inbox.title") };
}

export default async function InboxPage() {
  const supabase = await createClient();
  const current = await getCurrentUser(supabase);
  if (!current) redirect("/onboarding");

  const t = await getTranslator();

  // All four reads are RLS-filtered, so this is exactly what the caller may see.
  const [threads, attention, members, overviews] = await Promise.all([
    getInboxThreads(supabase),
    getAttention(supabase),
    getCompanyMembers(supabase),
    getProjectOverviews(supabase),
  ]);

  const projects = overviews
    .filter((o): o is typeof o & { id: string; name: string } =>
      Boolean(o.id && o.name)
    )
    .map((o) => ({ id: o.id, name: o.name }));

  return (
    <div className="mx-auto max-w-4xl px-4 py-6 sm:px-6">
      <header className="mb-6">
        <h1 className="text-2xl font-black tracking-tight text-slate-900">
          {t("inbox.title")}
        </h1>
        <p className="mt-1 text-sm text-slate-500">{t("inbox.subtitle")}</p>
      </header>

      <InboxView
        threads={threads}
        attention={attention}
        people={members.map((m) => ({
          id: m.id,
          full_name: m.full_name,
          role: m.role,
        }))}
        projects={projects}
        currentUserId={current.userId}
      />
    </div>
  );
}
