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
import { RoleBadge } from "@/components/status-pill";
import type { Company, Profile } from "@/lib/queries";
import { createClient } from "@/lib/supabase/client";

export function SettingsForms({
  profile,
  company,
  email,
}: {
  profile: Profile;
  company: Company;
  email: string | null;
}) {
  const router = useRouter();
  const [fullName, setFullName] = useState(profile.full_name);
  const [phone, setPhone] = useState(profile.phone ?? "");
  const [companyName, setCompanyName] = useState(company.name);
  const [profileError, setProfileError] = useState<string | null>(null);
  const [companyError, setCompanyError] = useState<string | null>(null);
  const [profileSaved, setProfileSaved] = useState(false);
  const [companySaved, setCompanySaved] = useState(false);
  const [busy, setBusy] = useState(false);

  const isOwner = profile.role === "owner";

  async function handleProfileSave(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setProfileError(null);
    setProfileSaved(false);
    const supabase = createClient();
    const { error } = await supabase
      .from("profiles")
      .update({ full_name: fullName.trim(), phone: phone.trim() || null })
      .eq("id", profile.id);
    setBusy(false);
    if (error) {
      setProfileError(error.message);
      return;
    }
    setProfileSaved(true);
    router.refresh();
  }

  async function handleCompanySave(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setCompanyError(null);
    setCompanySaved(false);
    const supabase = createClient();
    const { error } = await supabase
      .from("companies")
      .update({ name: companyName.trim() })
      .eq("id", company.id);
    setBusy(false);
    if (error) {
      setCompanyError(error.message);
      return;
    }
    setCompanySaved(true);
    router.refresh();
  }

  async function handleSignOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  return (
    <div className="space-y-6">
      <form
        onSubmit={handleProfileSave}
        className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
      >
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold text-slate-900">Profile</h2>
          <RoleBadge role={profile.role} />
        </div>
        <p className="text-sm text-slate-500">{email ?? ""}</p>
        <div>
          <label htmlFor="set-name" className={labelClass}>
            Full name
          </label>
          <input
            id="set-name"
            className={inputClass}
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            required
          />
        </div>
        <div>
          <label htmlFor="set-phone" className={labelClass}>
            Phone
          </label>
          <input
            id="set-phone"
            type="tel"
            className={inputClass}
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="+1 555 0100"
          />
        </div>
        <ErrorNote message={profileError} />
        <div className="flex items-center gap-3">
          <button type="submit" disabled={busy} className={primaryButtonClass}>
            Save profile
          </button>
          {profileSaved && (
            <span className="text-sm font-semibold text-emerald-700">
              Saved ✓
            </span>
          )}
        </div>
      </form>

      <form
        onSubmit={handleCompanySave}
        className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
      >
        <h2 className="text-lg font-bold text-slate-900">Company</h2>
        <div>
          <label htmlFor="set-company" className={labelClass}>
            Company name
          </label>
          <input
            id="set-company"
            className={inputClass}
            value={companyName}
            onChange={(e) => setCompanyName(e.target.value)}
            required
            disabled={!isOwner}
          />
          {!isOwner && (
            <p className="mt-1 text-xs text-slate-500">
              Only the owner can rename the company.
            </p>
          )}
        </div>
        <ErrorNote message={companyError} />
        {isOwner && (
          <div className="flex items-center gap-3">
            <button type="submit" disabled={busy} className={primaryButtonClass}>
              Save company
            </button>
            {companySaved && (
              <span className="text-sm font-semibold text-emerald-700">
                Saved ✓
              </span>
            )}
          </div>
        )}
      </form>

      <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="mb-3 text-lg font-bold text-slate-900">Session</h2>
        <button
          type="button"
          onClick={handleSignOut}
          className={secondaryButtonClass}
        >
          Sign out
        </button>
      </div>
    </div>
  );
}
