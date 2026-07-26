"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import {
  ErrorNote,
  inputClass,
  labelClass,
  primaryButtonClass,
} from "@/components/form";
import { useTranslator } from "@/i18n/client";
import type { Tables } from "@/lib/database.types";
import { createClient } from "@/lib/supabase/client";

type BillingSettings = Tables<"company_billing_settings">;
type MwstStatus = BillingSettings["mwst_status"];

/**
 * A QR-IBAN is a CH/LI IBAN whose institution identification (positions 5–9)
 * falls in the reserved 30000–31999 range. Mirrored from app.is_qr_iban so the
 * form can *explain* the consequence while typing; the database remains the
 * authority, and its CHECK constraint is what actually decides.
 */
function isQrIban(raw: string): boolean {
  const iban = raw.replace(/\s/g, "").toUpperCase();
  if (!/^(CH|LI)[0-9]{2}[0-9]{5}[A-Z0-9]{12}$/.test(iban)) return false;
  const iid = Number(iban.slice(4, 9));
  return iid >= 30000 && iid <= 31999;
}

function ibanShapeOk(raw: string): boolean {
  return /^(CH|LI)[0-9]{2}[A-Z0-9]{17}$/.test(raw.replace(/\s/g, "").toUpperCase());
}

export function BillingForm({
  companyId,
  initial,
}: {
  companyId: string;
  initial: BillingSettings | null;
}) {
  const router = useRouter();
  const t = useTranslator();

  const [name, setName] = useState(initial?.creditor_name ?? "");
  const [street, setStreet] = useState(initial?.creditor_street ?? "");
  const [buildingNo, setBuildingNo] = useState(initial?.creditor_building_no ?? "");
  const [postCode, setPostCode] = useState(initial?.creditor_post_code ?? "");
  const [town, setTown] = useState(initial?.creditor_town ?? "");
  const [iban, setIban] = useState(initial?.iban ?? "");
  const [mwstStatus, setMwstStatus] = useState<MwstStatus>(
    initial?.mwst_status ?? "not_registered"
  );
  const [uid, setUid] = useState(initial?.uid_digits ?? "");
  const [hourlyRate, setHourlyRate] = useState(
    initial ? String(initial.default_hourly_rate_rappen / 100) : "95"
  );
  const [paymentTerms, setPaymentTerms] = useState(
    String(initial?.payment_terms_days ?? 30)
  );
  const [showPrices, setShowPrices] = useState(
    initial?.show_prices_on_rapport ?? false
  );

  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);

  const cleanIban = iban.replace(/\s/g, "").toUpperCase();
  const ibanValid = cleanIban === "" || ibanShapeOk(cleanIban);
  const qrIban = isQrIban(cleanIban);
  const registered = mwstStatus !== "not_registered";

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setSaved(false);

    const supabase = createClient();
    const { error: upsertError } = await supabase
      .from("company_billing_settings")
      .upsert(
        {
          company_id: companyId,
          creditor_name: name.trim(),
          creditor_street: street.trim() || null,
          creditor_building_no: buildingNo.trim() || null,
          creditor_post_code: postCode.trim(),
          creditor_town: town.trim(),
          creditor_country: "CH",
          iban: cleanIban || null,
          mwst_status: mwstStatus,
          // The database refuses a registered company without a UID; sending an
          // empty string instead of null would trip the format check first and
          // report the wrong problem.
          uid_digits: uid.replace(/\D/g, "") || null,
          default_hourly_rate_rappen: Math.round(
            Number(hourlyRate.replace(",", ".") || 0) * 100
          ),
          payment_terms_days: Number(paymentTerms) || 30,
          show_prices_on_rapport: showPrices,
        },
        { onConflict: "company_id" }
      );

    setBusy(false);
    if (upsertError) {
      setError(upsertError.message);
      return;
    }
    setSaved(true);
    router.refresh();
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
    >
      <h2 className="mb-1 text-lg font-bold text-slate-900">
        {t("billing.title")}
      </h2>
      <p className="mb-4 text-sm text-slate-500">{t("billing.intro")}</p>

      <div className="space-y-4">
        <div>
          <label htmlFor="b-name" className={labelClass}>
            {t("billing.creditorName")}
          </label>
          <input
            id="b-name"
            className={inputClass}
            value={name}
            onChange={(e) => setName(e.target.value)}
            maxLength={70}
            required
          />
        </div>

        {/* Structured address: v2.3 removed the combined form, so street and
            building number are separate fields rather than one line. */}
        <div className="flex gap-3">
          <div className="flex-1">
            <label htmlFor="b-street" className={labelClass}>
              {t("billing.street")}
            </label>
            <input
              id="b-street"
              className={inputClass}
              value={street}
              onChange={(e) => setStreet(e.target.value)}
              maxLength={70}
            />
          </div>
          <div className="w-28">
            <label htmlFor="b-no" className={labelClass}>
              {t("billing.buildingNo")}
            </label>
            <input
              id="b-no"
              className={inputClass}
              value={buildingNo}
              onChange={(e) => setBuildingNo(e.target.value)}
              maxLength={16}
            />
          </div>
        </div>

        <div className="flex gap-3">
          <div className="w-32">
            <label htmlFor="b-plz" className={labelClass}>
              {t("billing.postCode")}
            </label>
            <input
              id="b-plz"
              className={inputClass}
              value={postCode}
              onChange={(e) => setPostCode(e.target.value)}
              maxLength={16}
              required
            />
          </div>
          <div className="flex-1">
            <label htmlFor="b-town" className={labelClass}>
              {t("billing.town")}
            </label>
            <input
              id="b-town"
              className={inputClass}
              value={town}
              onChange={(e) => setTown(e.target.value)}
              maxLength={35}
              required
            />
          </div>
        </div>

        <div>
          <label htmlFor="b-iban" className={labelClass}>
            {t("billing.iban")}
          </label>
          <input
            id="b-iban"
            className={inputClass}
            value={iban}
            onChange={(e) => setIban(e.target.value)}
            placeholder="CH.. .... .... .... .... ."
            aria-invalid={!ibanValid}
          />
          {/* The reference type is derived from the IBAN, never asked. Saying
              so here is the difference between a surprising invoice and an
              understood one. */}
          {cleanIban !== "" && !ibanValid && (
            <p className="mt-1 text-xs font-semibold text-red-700">
              {t("billing.ibanInvalid")}
            </p>
          )}
          {ibanValid && cleanIban !== "" && (
            <p className="mt-1 text-xs text-slate-500">
              {qrIban ? t("billing.qrIbanDetected") : t("billing.plainIban")}
            </p>
          )}
        </div>

        <div>
          <label htmlFor="b-mwst" className={labelClass}>
            {t("billing.mwstStatus")}
          </label>
          <select
            id="b-mwst"
            className={inputClass}
            value={mwstStatus}
            onChange={(e) => setMwstStatus(e.target.value as MwstStatus)}
          >
            <option value="not_registered">{t("billing.mwst.none")}</option>
            <option value="registered_effective">
              {t("billing.mwst.effective")}
            </option>
            <option value="registered_saldo">{t("billing.mwst.saldo")}</option>
          </select>
          {!registered && (
            <p className="mt-1 text-xs text-slate-500">
              {t("billing.mwstNoneNote")}
            </p>
          )}
        </div>

        {registered && (
          <div>
            <label htmlFor="b-uid" className={labelClass}>
              {t("billing.uid")}
            </label>
            <input
              id="b-uid"
              className={inputClass}
              value={uid}
              onChange={(e) => setUid(e.target.value)}
              placeholder="CHE-123.456.789"
              required
            />
            <p className="mt-1 text-xs text-slate-500">{t("billing.uidNote")}</p>
          </div>
        )}

        <div className="flex gap-3">
          <div className="flex-1">
            <label htmlFor="b-rate" className={labelClass}>
              {t("billing.hourlyRate")}
            </label>
            <input
              id="b-rate"
              className={inputClass}
              value={hourlyRate}
              onChange={(e) => setHourlyRate(e.target.value)}
              inputMode="decimal"
            />
          </div>
          <div className="w-36">
            <label htmlFor="b-terms" className={labelClass}>
              {t("billing.paymentTerms")}
            </label>
            <input
              id="b-terms"
              type="number"
              min={1}
              max={365}
              className={inputClass}
              value={paymentTerms}
              onChange={(e) => setPaymentTerms(e.target.value)}
            />
          </div>
        </div>

        <label className="flex cursor-pointer items-start gap-3">
          <input
            type="checkbox"
            checked={showPrices}
            onChange={(e) => setShowPrices(e.target.checked)}
            className="mt-1 size-4 accent-slate-900"
          />
          <span className="text-sm">
            <span className="font-medium text-slate-800">
              {t("billing.showPrices")}
            </span>
            <span className="mt-0.5 block text-xs text-slate-500">
              {t("billing.showPricesNote")}
            </span>
          </span>
        </label>

        <ErrorNote message={error} />
        {saved && (
          <p className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
            {t("billing.saved")}
          </p>
        )}

        <button
          type="submit"
          disabled={busy || !ibanValid}
          className={primaryButtonClass}
        >
          {busy ? t("billing.saving") : t("billing.save")}
        </button>
      </div>
    </form>
  );
}
