"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import {
  ErrorNote,
  inputClass,
  labelClass,
  primaryButtonClass,
  secondaryButtonClass,
} from "@/components/form";
import { useTranslator } from "@/i18n/client";
import { createClient } from "@/lib/supabase/client";

type Tab = "invite" | "company";

export function OnboardingForm({
  defaultFullName,
}: {
  defaultFullName: string;
}) {
  const t = useTranslator();
  const router = useRouter();
  const [tab, setTab] = useState<Tab>("invite");
  const [fullName, setFullName] = useState(defaultFullName);
  const [inviteCode, setInviteCode] = useState("");
  const [companyName, setCompanyName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    const supabase = createClient();

    if (tab === "invite") {
      const { data, error: rpcError } = await supabase.rpc("redeem_invite", {
        p_code: inviteCode.trim(),
        p_full_name: fullName.trim(),
      });
      if (rpcError) {
        setError(rpcError.message);
        setBusy(false);
        return;
      }
      if (!data) {
        setError(t("auth.inviteCodeInvalid"));
        setBusy(false);
        return;
      }
    } else {
      const { error: rpcError } = await supabase.rpc("create_company", {
        p_name: companyName.trim(),
        p_full_name: fullName.trim(),
      });
      if (rpcError) {
        setError(rpcError.message);
        setBusy(false);
        return;
      }
    }

    router.push("/");
    router.refresh();
  }

  async function handleSignOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  const tabClass = (active: boolean) =>
    `flex-1 rounded-lg px-3 py-2.5 text-sm font-semibold transition-colors ${
      active ? "bg-slate-900 text-white" : "text-slate-600 hover:bg-slate-100"
    }`;

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
      <div className="mb-5 flex gap-2 rounded-xl bg-slate-50 p-1">
        <button
          type="button"
          className={tabClass(tab === "invite")}
          onClick={() => {
            setTab("invite");
            setError(null);
          }}
        >
          {t("auth.enterInviteCode")}
        </button>
        <button
          type="button"
          className={tabClass(tab === "company")}
          onClick={() => {
            setTab("company");
            setError(null);
          }}
        >
          {t("auth.createCompany")}
        </button>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="ob-name" className={labelClass}>
            {t("auth.yourFullName")}
          </label>
          <input
            id="ob-name"
            className={inputClass}
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            required
            autoComplete="name"
          />
        </div>

        {tab === "invite" ? (
          <div>
            <label htmlFor="ob-code" className={labelClass}>
              {t("auth.inviteCode")}
            </label>
            <input
              id="ob-code"
              className={`${inputClass} font-mono uppercase tracking-widest`}
              value={inviteCode}
              onChange={(e) => setInviteCode(e.target.value.toUpperCase())}
              required
              placeholder={t("auth.inviteCodePlaceholder")}
              maxLength={16}
            />
          </div>
        ) : (
          <div>
            <label htmlFor="ob-company" className={labelClass}>
              {t("auth.companyName")}
            </label>
            <input
              id="ob-company"
              className={inputClass}
              value={companyName}
              onChange={(e) => setCompanyName(e.target.value)}
              required
              placeholder={t("auth.companyNamePlaceholder")}
            />
            <p className="mt-1 text-xs text-slate-500">
              {t("auth.companyOwnerNote")}
            </p>
          </div>
        )}

        <ErrorNote message={error} />

        <button type="submit" disabled={busy} className={`${primaryButtonClass} w-full`}>
          {busy
            ? t("common.working")
            : tab === "invite"
              ? t("auth.joinCompany")
              : t("auth.createCompany")}
        </button>
        <button
          type="button"
          onClick={handleSignOut}
          className={`${secondaryButtonClass} w-full`}
        >
          {t("nav.signOut")}
        </button>
      </form>
    </div>
  );
}
