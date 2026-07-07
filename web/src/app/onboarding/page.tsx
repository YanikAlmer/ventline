import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { OnboardingForm } from "@/components/auth/onboarding-form";
import { getCurrentUser } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Get set up" };

export default async function OnboardingPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const current = await getCurrentUser(supabase);
  if (current) redirect("/");

  const fallbackName =
    typeof user.user_metadata?.full_name === "string"
      ? user.user_metadata.full_name
      : "";

  return (
    <main className="flex min-h-dvh items-center justify-center bg-slate-100 px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-3 flex size-12 items-center justify-center rounded-xl bg-slate-900 text-xl font-black text-white">
            V
          </div>
          <h1 className="text-2xl font-black tracking-tight text-slate-900">
            Almost there
          </h1>
          <p className="mt-1 text-sm text-slate-500">
            Your account needs a company. Create one, or join with an invite
            code.
          </p>
        </div>
        <OnboardingForm defaultFullName={fallbackName} />
      </div>
    </main>
  );
}
