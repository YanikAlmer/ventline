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
import type { Profile } from "@/lib/queries";
import { createClient } from "@/lib/supabase/client";

type Member = Pick<Profile, "id" | "full_name" | "role">;

export function NewTaskButton({
  projectId,
  companyId,
  members,
}: {
  projectId: string;
  companyId: string;
  members: Member[];
}) {
  const router = useRouter();
  const t = useTranslator();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [assignees, setAssignees] = useState<string[]>([]);
  const [visibleToCustomer, setVisibleToCustomer] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  function toggleAssignee(id: string) {
    setAssignees((prev) =>
      prev.includes(id) ? prev.filter((a) => a !== id) : [...prev, id]
    );
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    const supabase = createClient();

    const { data: task, error: insertError } = await supabase
      .from("tasks")
      .insert({
        project_id: projectId,
        company_id: companyId,
        title: title.trim(),
        description: description.trim() || null,
        due_date: dueDate || null,
        visible_to_customer: visibleToCustomer,
      })
      .select("id")
      .single();

    if (insertError || !task) {
      setError(insertError?.message ?? t("tasks.new.createFailed"));
      setBusy(false);
      return;
    }

    if (assignees.length > 0) {
      const { error: assignError } = await supabase
        .from("task_assignments")
        .insert(
          assignees.map((profileId) => ({
            task_id: task.id,
            profile_id: profileId,
          }))
        );
      if (assignError) {
        setError(
          t("tasks.new.assignFailed", { message: assignError.message })
        );
        setBusy(false);
        router.refresh();
        return;
      }
    }

    setBusy(false);
    setOpen(false);
    setTitle("");
    setDescription("");
    setDueDate("");
    setAssignees([]);
    setVisibleToCustomer(false);
    router.refresh();
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={primaryButtonClass}
      >
        + {t("tasks.new.title")}
      </button>

      {open && (
        <Modal title={t("tasks.new.title")} onClose={() => setOpen(false)}>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label htmlFor="nt-title" className={labelClass}>
                {t("tasks.new.titleLabel")}
              </label>
              <input
                id="nt-title"
                className={inputClass}
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
                placeholder={t("tasks.new.titlePlaceholder")}
              />
            </div>
            <div>
              <label htmlFor="nt-description" className={labelClass}>
                {t("tasks.new.descriptionLabel")}
              </label>
              <textarea
                id="nt-description"
                className={inputClass}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={3}
              />
            </div>
            <div>
              <label htmlFor="nt-due" className={labelClass}>
                {t("tasks.new.dueDateLabel")}
              </label>
              <input
                id="nt-due"
                type="date"
                className={inputClass}
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
              />
            </div>

            <fieldset>
              <legend className={labelClass}>
                {t("tasks.new.assigneesLabel")}
              </legend>
              {members.length === 0 ? (
                <p className="text-sm text-slate-500">
                  {t("tasks.new.noMembers")}
                </p>
              ) : (
                <div className="max-h-44 space-y-1 overflow-y-auto rounded-lg border border-slate-200 p-2">
                  {members.map((m) => (
                    <label
                      key={m.id}
                      className="flex min-h-10 cursor-pointer items-center gap-3 rounded-md px-2 py-1.5 hover:bg-slate-50"
                    >
                      <input
                        type="checkbox"
                        checked={assignees.includes(m.id)}
                        onChange={() => toggleAssignee(m.id)}
                        className="size-4 accent-slate-900"
                      />
                      <span className="text-sm font-medium text-slate-800">
                        {m.full_name}
                      </span>
                    </label>
                  ))}
                </div>
              )}
            </fieldset>

            <label className="flex min-h-11 cursor-pointer items-center gap-3">
              <input
                type="checkbox"
                checked={visibleToCustomer}
                onChange={(e) => setVisibleToCustomer(e.target.checked)}
                className="size-4 accent-slate-900"
              />
              <span className="text-sm font-medium text-slate-800">
                {t("tasks.new.visibleToCustomer")}
              </span>
            </label>

            <ErrorNote message={error} />
            <button
              type="submit"
              disabled={busy}
              className={`${primaryButtonClass} w-full`}
            >
              {busy ? t("tasks.new.creating") : t("tasks.new.submit")}
            </button>
          </form>
        </Modal>
      )}
    </>
  );
}
