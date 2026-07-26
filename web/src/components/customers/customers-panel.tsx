"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import {
  ErrorNote,
  dangerButtonClass,
  inputClass,
  labelClass,
  primaryButtonClass,
  secondaryButtonClass,
} from "@/components/form";
import { Modal } from "@/components/modal";
import { useTranslator } from "@/i18n/client";
import type { Tables } from "@/lib/database.types";
import { createClient } from "@/lib/supabase/client";

type Customer = Tables<"customers">;

export function CustomersPanel({
  companyId,
  initial,
  canEdit,
}: {
  companyId: string;
  initial: Customer[];
  canEdit: boolean;
}) {
  const router = useRouter();
  const t = useTranslator();
  const [editing, setEditing] = useState<Customer | "new" | null>(null);

  return (
    <div>
      <div className="mb-4 flex items-center justify-between gap-3">
        <h1 className="text-2xl font-black tracking-tight text-slate-900">
          {t("customers.title")}{" "}
          <span className="text-base font-semibold text-slate-400">
            {initial.length}
          </span>
        </h1>
        {canEdit && (
          <button
            type="button"
            onClick={() => setEditing("new")}
            className={primaryButtonClass}
          >
            + {t("customers.new")}
          </button>
        )}
      </div>

      {initial.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center text-sm text-slate-500">
          {t("customers.empty")}
        </div>
      ) : (
        <ul className="space-y-2">
          {initial.map((customer) => (
            <li key={customer.id}>
              <button
                type="button"
                onClick={() => canEdit && setEditing(customer)}
                disabled={!canEdit}
                className="flex w-full items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 text-left shadow-sm transition-shadow enabled:hover:shadow-md"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold text-slate-900">
                    {customer.name}
                  </p>
                  <p className="mt-0.5 truncate text-xs text-slate-500">
                    {[
                      [customer.street, customer.building_no]
                        .filter(Boolean)
                        .join(" "),
                      [customer.post_code, customer.town]
                        .filter(Boolean)
                        .join(" "),
                    ]
                      .filter(Boolean)
                      .join(", ") || t("customers.noAddress")}
                  </p>
                </div>
                {!customer.post_code && (
                  <span className="shrink-0 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-800">
                    {t("customers.addressMissing")}
                  </span>
                )}
              </button>
            </li>
          ))}
        </ul>
      )}

      {editing && (
        <CustomerModal
          companyId={companyId}
          customer={editing === "new" ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            router.refresh();
          }}
        />
      )}
    </div>
  );
}

function CustomerModal({
  companyId,
  customer,
  onClose,
  onSaved,
}: {
  companyId: string;
  customer: Customer | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const t = useTranslator();
  const [name, setName] = useState(customer?.name ?? "");
  const [street, setStreet] = useState(customer?.street ?? "");
  const [buildingNo, setBuildingNo] = useState(customer?.building_no ?? "");
  const [postCode, setPostCode] = useState(customer?.post_code ?? "");
  const [town, setTown] = useState(customer?.town ?? "");
  const [email, setEmail] = useState(customer?.email ?? "");
  const [phone, setPhone] = useState(customer?.phone ?? "");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // The address is all-or-nothing in the database, because a half-filled
  // debtor block renders a broken payment part. Say so before the save fails.
  const partial =
    [postCode, town].some((v) => v.trim() !== "") &&
    [postCode, town].some((v) => v.trim() === "");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const supabase = createClient();

    const hasAddress = postCode.trim() !== "" && town.trim() !== "";
    const payload = {
      company_id: companyId,
      name: name.trim(),
      street: street.trim() || null,
      building_no: buildingNo.trim() || null,
      post_code: hasAddress ? postCode.trim() : null,
      town: hasAddress ? town.trim() : null,
      country: hasAddress ? "CH" : null,
      email: email.trim() || null,
      phone: phone.trim() || null,
    };

    const { error: saveError } = customer
      ? await supabase.from("customers").update(payload).eq("id", customer.id)
      : await supabase.from("customers").insert(payload);

    setBusy(false);
    if (saveError) {
      setError(saveError.message);
      return;
    }
    onSaved();
  }

  async function handleDelete() {
    if (!customer) return;
    setBusy(true);
    const supabase = createClient();
    const { error: delError } = await supabase
      .from("customers")
      .delete()
      .eq("id", customer.id);
    setBusy(false);
    if (delError) {
      setError(delError.message);
      return;
    }
    onSaved();
  }

  return (
    <Modal
      title={customer ? t("customers.edit") : t("customers.new")}
      onClose={onClose}
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="c-name" className={labelClass}>
            {t("customers.name")}
          </label>
          <input
            id="c-name"
            className={inputClass}
            value={name}
            onChange={(e) => setName(e.target.value)}
            maxLength={70}
            required
          />
        </div>

        <div className="flex gap-3">
          <div className="flex-1">
            <label htmlFor="c-street" className={labelClass}>
              {t("billing.street")}
            </label>
            <input
              id="c-street"
              className={inputClass}
              value={street}
              onChange={(e) => setStreet(e.target.value)}
              maxLength={70}
            />
          </div>
          <div className="w-24">
            <label htmlFor="c-no" className={labelClass}>
              {t("billing.buildingNo")}
            </label>
            <input
              id="c-no"
              className={inputClass}
              value={buildingNo}
              onChange={(e) => setBuildingNo(e.target.value)}
              maxLength={16}
            />
          </div>
        </div>

        <div className="flex gap-3">
          <div className="w-28">
            <label htmlFor="c-plz" className={labelClass}>
              {t("billing.postCode")}
            </label>
            <input
              id="c-plz"
              className={inputClass}
              value={postCode}
              onChange={(e) => setPostCode(e.target.value)}
              maxLength={16}
            />
          </div>
          <div className="flex-1">
            <label htmlFor="c-town" className={labelClass}>
              {t("billing.town")}
            </label>
            <input
              id="c-town"
              className={inputClass}
              value={town}
              onChange={(e) => setTown(e.target.value)}
              maxLength={35}
            />
          </div>
        </div>
        {partial && (
          <p className="text-xs font-semibold text-amber-700">
            {t("customers.addressAllOrNothing")}
          </p>
        )}

        <div className="flex gap-3">
          <div className="flex-1">
            <label htmlFor="c-email" className={labelClass}>
              {t("customers.email")}
            </label>
            <input
              id="c-email"
              type="email"
              className={inputClass}
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div className="flex-1">
            <label htmlFor="c-phone" className={labelClass}>
              {t("customers.phone")}
            </label>
            <input
              id="c-phone"
              className={inputClass}
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
            />
          </div>
        </div>

        <ErrorNote message={error} />

        <div className="flex gap-2">
          <button
            type="submit"
            disabled={busy}
            className={`${primaryButtonClass} flex-1`}
          >
            {busy ? t("customers.saving") : t("customers.save")}
          </button>
          {customer && (
            <button
              type="button"
              onClick={handleDelete}
              disabled={busy}
              className={dangerButtonClass}
            >
              {t("customers.delete")}
            </button>
          )}
          <button type="button" onClick={onClose} className={secondaryButtonClass}>
            {t("customers.cancel")}
          </button>
        </div>
      </form>
    </Modal>
  );
}
