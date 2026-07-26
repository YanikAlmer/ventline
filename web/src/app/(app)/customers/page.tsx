import type { Metadata } from "next";

import { CustomersPanel } from "@/components/customers/customers-panel";
import { getTranslator } from "@/i18n/server";
import { getCurrentUser } from "@/lib/queries";
import { isOffice } from "@/lib/status";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("customers.title") };
}

export default async function CustomersPage() {
  const supabase = await createClient();
  const current = await getCurrentUser(supabase);
  if (!current) return null;

  const { data } = await supabase
    .from("customers")
    .select("*")
    .order("name", { ascending: true });

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 sm:px-6">
      <CustomersPanel
        companyId={current.company.id}
        initial={data ?? []}
        canEdit={isOffice(current.profile.role)}
      />
    </div>
  );
}
