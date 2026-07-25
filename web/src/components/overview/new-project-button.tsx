"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import {
  ErrorNote,
  inputClass,
  labelClass,
  primaryButtonClass,
} from "@/components/form";
import { Modal } from "@/components/modal";
import { useTranslator } from "@/i18n/client";
import { PROJECT_STATUSES, type ProjectStatus } from "@/lib/status";
import { createClient } from "@/lib/supabase/client";

export function NewProjectButton() {
  const router = useRouter();
  const t = useTranslator();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [address, setAddress] = useState("");
  const [description, setDescription] = useState("");
  const [status, setStatus] = useState<ProjectStatus>("planning");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    const supabase = createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { data: profile } = user
      ? await supabase
          .from("profiles")
          .select("company_id")
          .eq("id", user.id)
          .maybeSingle()
      : { data: null };
    if (!profile) {
      setError(t("projects.new.profileError"));
      setBusy(false);
      return;
    }

    const { data: created, error: insertError } = await supabase
      .from("projects")
      .insert({
        company_id: profile.company_id,
        name: name.trim(),
        address: address.trim() || null,
        description: description.trim() || null,
        status,
      })
      .select("id")
      .single();

    if (insertError || !created) {
      setError(insertError?.message ?? t("projects.new.createError"));
      setBusy(false);
      return;
    }

    setOpen(false);
    setBusy(false);
    setName("");
    setAddress("");
    setDescription("");
    setStatus("planning");
    router.push(`/projects/${created.id}`);
    router.refresh();
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={primaryButtonClass}
      >
        + {t("projects.new.title")}
      </button>

      {open && (
        <Modal title={t("projects.new.title")} onClose={() => setOpen(false)}>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label htmlFor="np-name" className={labelClass}>
                {t("projects.new.name")}
              </label>
              <input
                id="np-name"
                className={inputClass}
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
                placeholder={t("projects.new.namePlaceholder")}
              />
            </div>
            <div>
              <label htmlFor="np-address" className={labelClass}>
                {t("projects.new.address")}
              </label>
              <input
                id="np-address"
                className={inputClass}
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                placeholder={t("projects.new.addressPlaceholder")}
              />
            </div>
            <div>
              <label htmlFor="np-description" className={labelClass}>
                {t("projects.new.description")}
              </label>
              <textarea
                id="np-description"
                className={inputClass}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={3}
              />
            </div>
            <div>
              <label htmlFor="np-status" className={labelClass}>
                {t("projects.new.status")}
              </label>
              <select
                id="np-status"
                className={inputClass}
                value={status}
                onChange={(e) => setStatus(e.target.value as ProjectStatus)}
              >
                {PROJECT_STATUSES.map((s) => (
                  <option key={s} value={s}>
                    {t(`status.project.${s}`)}
                  </option>
                ))}
              </select>
            </div>
            <ErrorNote message={error} />
            <button
              type="submit"
              disabled={busy}
              className={`${primaryButtonClass} w-full`}
            >
              {busy ? t("projects.new.creating") : t("projects.new.submit")}
            </button>
          </form>
        </Modal>
      )}
    </>
  );
}
