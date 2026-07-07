import { redirect } from "next/navigation";

import { PortalHeader } from "@/components/portal/portal-header";
import { getCurrentUser } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export default async function PortalLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const supabase = await createClient();
  const current = await getCurrentUser(supabase);

  if (!current) redirect("/onboarding");
  if (current.profile.role !== "customer") redirect("/");

  return (
    <div className="min-h-dvh bg-slate-50">
      <PortalHeader
        companyName={current.company.name}
        userName={current.profile.full_name}
      />
      <main className="mx-auto max-w-3xl px-4 py-6 sm:px-6">{children}</main>
    </div>
  );
}
