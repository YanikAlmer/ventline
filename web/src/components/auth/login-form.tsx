"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import {
  ErrorNote,
  inputClass,
  labelClass,
  primaryButtonClass,
} from "@/components/form";
import { createClient } from "@/lib/supabase/client";

type Mode = "sign_in" | "sign_up";
type SignupPath = "invite" | "company";

export function LoginForm() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("sign_in");
  const [signupPath, setSignupPath] = useState<SignupPath>("invite");
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [inviteCode, setInviteCode] = useState("");
  const [companyName, setCompanyName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    const supabase = createClient();

    if (mode === "sign_in") {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (signInError) {
        setError(signInError.message);
        setBusy(false);
        return;
      }
    } else {
      const metadata: Record<string, string> = { full_name: fullName.trim() };
      if (signupPath === "invite") metadata.invite_code = inviteCode.trim();
      else metadata.company_name = companyName.trim();

      const { data, error: signUpError } = await supabase.auth.signUp({
        email,
        password,
        options: { data: metadata },
      });
      if (signUpError) {
        setError(signUpError.message);
        setBusy(false);
        return;
      }
      if (!data.session) {
        setError(
          "Check your email to confirm your account, then sign in here."
        );
        setBusy(false);
        return;
      }

      // A session exists, but the profile bootstrap (handle_new_user trigger)
      // may not have created a profile — most commonly an invalid/expired
      // invite code. Without this check the user is silently bounced to
      // /onboarding with no explanation. Surface a clear error instead.
      const { data: profileRow } = await supabase
        .from("profiles")
        .select("id")
        .eq("id", data.session.user.id)
        .maybeSingle();
      if (!profileRow) {
        setError(
          signupPath === "invite"
            ? "That invite code is invalid or has expired. Double-check the code and try again."
            : "We couldn't finish setting up your company. Please try again."
        );
        setBusy(false);
        return;
      }
    }

    router.push("/");
    router.refresh();
  }

  const tabClass = (active: boolean) =>
    `flex-1 rounded-lg px-3 py-2.5 text-sm font-semibold transition-colors ${
      active
        ? "bg-slate-900 text-white"
        : "text-slate-600 hover:bg-slate-100"
    }`;

  const subTabClass = (active: boolean) =>
    `flex-1 rounded-md px-3 py-2 text-sm font-semibold transition-colors ${
      active
        ? "bg-white text-slate-900 shadow-sm"
        : "text-slate-500 hover:text-slate-800"
    }`;

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
      <div className="mb-5 flex gap-2 rounded-xl bg-slate-50 p-1">
        <button
          type="button"
          className={tabClass(mode === "sign_in")}
          onClick={() => {
            setMode("sign_in");
            setError(null);
          }}
        >
          Sign in
        </button>
        <button
          type="button"
          className={tabClass(mode === "sign_up")}
          onClick={() => {
            setMode("sign_up");
            setError(null);
          }}
        >
          Sign up
        </button>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        {mode === "sign_up" && (
          <div>
            <label htmlFor="full-name" className={labelClass}>
              Full name
            </label>
            <input
              id="full-name"
              className={inputClass}
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              required
              autoComplete="name"
              placeholder="Alex Alvarez"
            />
          </div>
        )}

        <div>
          <label htmlFor="email" className={labelClass}>
            Email
          </label>
          <input
            id="email"
            type="email"
            className={inputClass}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoComplete="email"
            placeholder="you@company.com"
          />
        </div>

        <div>
          <label htmlFor="password" className={labelClass}>
            Password
          </label>
          <input
            id="password"
            type="password"
            className={inputClass}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            minLength={6}
            autoComplete={mode === "sign_in" ? "current-password" : "new-password"}
          />
        </div>

        {mode === "sign_up" && (
          <div className="space-y-3">
            <div className="flex gap-1 rounded-lg bg-slate-100 p-1">
              <button
                type="button"
                className={subTabClass(signupPath === "invite")}
                onClick={() => setSignupPath("invite")}
              >
                I have an invite code
              </button>
              <button
                type="button"
                className={subTabClass(signupPath === "company")}
                onClick={() => setSignupPath("company")}
              >
                New company
              </button>
            </div>

            {signupPath === "invite" ? (
              <div>
                <label htmlFor="invite-code" className={labelClass}>
                  Invite code
                </label>
                <input
                  id="invite-code"
                  className={`${inputClass} font-mono uppercase tracking-widest`}
                  value={inviteCode}
                  onChange={(e) => setInviteCode(e.target.value.toUpperCase())}
                  required
                  placeholder="ABCD2345"
                  maxLength={16}
                />
              </div>
            ) : (
              <div>
                <label htmlFor="company-name" className={labelClass}>
                  Company name
                </label>
                <input
                  id="company-name"
                  className={inputClass}
                  value={companyName}
                  onChange={(e) => setCompanyName(e.target.value)}
                  required
                  placeholder="Alpine Air HVAC"
                />
                <p className="mt-1 text-xs text-slate-500">
                  You will be the company owner.
                </p>
              </div>
            )}
          </div>
        )}

        <ErrorNote message={error} />

        <button type="submit" disabled={busy} className={`${primaryButtonClass} w-full`}>
          {busy
            ? "Working…"
            : mode === "sign_in"
              ? "Sign in"
              : "Create account"}
        </button>
      </form>
    </div>
  );
}
