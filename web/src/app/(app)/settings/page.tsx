import type { Metadata } from "next";

import { BillingForm } from "@/components/settings/billing-form";
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

  // Billing identity is office-only, and the RLS policy already enforces that —
  // a worker's query simply returns nothing, so the section is hidden rather
  // than rendered empty.
  const { data: billing } = await supabase
    .from("company_billing_settings")
    .select("*")
    .eq("company_id", current.company.id)
    .maybeSingle();

  const isOfficeRole =
    current.profile.role === "owner" || current.profile.role === "manager";

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

      {isOfficeRole && (
        <div className="mt-6">
          <BillingForm companyId={current.company.id} initial={billing} />
        </div>
      )}
    </div>
  );
}
