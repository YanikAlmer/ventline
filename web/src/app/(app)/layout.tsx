import { redirect } from "next/navigation";

import { Sidebar } from "@/components/sidebar";
import { getCurrentUser } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export default async function AppLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const supabase = await createClient();
  const current = await getCurrentUser(supabase);

  if (!current) redirect("/onboarding");
  if (current.profile.role === "customer") redirect("/portal");

  return (
    <div className="flex min-h-dvh flex-col md:flex-row">
      <Sidebar
        companyName={current.company.name}
        userName={current.profile.full_name}
        role={current.profile.role}
      />
      <main className="min-w-0 flex-1">{children}</main>
    </div>
  );
}
