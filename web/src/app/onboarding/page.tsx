import type { Metadata } from "next";
import { BrandMark } from "@/components/brand-mark";
import { redirect } from "next/navigation";

import { OnboardingForm } from "@/components/auth/onboarding-form";
import { getTranslator } from "@/i18n/server";
import { getCurrentUser } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslator();
  return { title: t("auth.getSetUp") };
}

export default async function OnboardingPage() {
  const t = await getTranslator();
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
          <div className="mx-auto mb-3 flex size-12 items-center justify-center rounded-xl bg-slate-900 p-2">
            <BrandMark className="size-full text-white" />
          </div>
          <h1 className="text-2xl font-black tracking-tight text-slate-900">
            {t("auth.almostThere")}
          </h1>
          <p className="mt-1 text-sm text-slate-500">
            {t("auth.onboardingIntro")}
          </p>
        </div>
        <OnboardingForm defaultFullName={fallbackName} />
      </div>
    </main>
  );
}
