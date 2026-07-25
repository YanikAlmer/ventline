import type { Metadata } from "next";

import { SettingsForms } from "@/components/settings/settings-forms";
import { getTranslator } from "@/i18n/server";
import { getCurrentUser } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("nav.settings") };
}

export default async function SettingsPage() {
  const supabase = await createClient();
  const current = await getCurrentUser(supabase);
  if (!current) return null;

  const t = await getTranslator();

  return (
    <div className="mx-auto max-w-2xl px-4 py-6 sm:px-6">
      <h1 className="mb-6 text-2xl font-black tracking-tight text-slate-900">
        {t("nav.settings")}
      </h1>
      <SettingsForms
        profile={current.profile}
        company={current.company}
        email={current.email}
      />
    </div>
  );
}
