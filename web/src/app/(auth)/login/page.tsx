import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { LoginForm } from "@/components/auth/login-form";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Sign in" };

export default async function LoginPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) redirect("/");

  return (
    <main className="flex min-h-dvh items-center justify-center bg-slate-100 px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-3 flex size-12 items-center justify-center rounded-xl bg-slate-900 text-xl font-black text-white">
            V
          </div>
          <h1 className="text-2xl font-black tracking-tight text-slate-900">
            Ventline
          </h1>
          <p className="mt-1 text-sm text-slate-500">
            Job-site communication for trades companies
          </p>
        </div>
        <LoginForm />
      </div>
    </main>
  );
}
