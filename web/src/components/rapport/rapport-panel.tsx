"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { ErrorNote, primaryButtonClass, secondaryButtonClass } from "@/components/form";
import { Modal } from "@/components/modal";
import { useTranslator } from "@/i18n/client";
import type {
  Customer,
  MaterialLine,
  Report,
  ReportMaterialLine,
  ReportTimeLine,
  TimeEntry,
} from "@/lib/rapport";
import { chf, hoursAndMinutes, quantity } from "@/lib/rapport";
import { createClient } from "@/lib/supabase/client";

/**
 * Every column of a Postgres view is nullable as far as the generated types
 * are concerned — the planner cannot promise otherwise — so this mirrors the
 * generated shape rather than asserting a stricter one that would be a lie.
 */
type Divergence = {
  report_id: string | null;
  number_text: string | null;
  minutes_on_paper: number | null;
  minutes_now: number | null;
  delta_minutes: number | null;
  source_was_voided: boolean | null;
};

/**
 * The office view of a job's Rapporte: what was recorded, what has been
 * signed, and where a signed document and its source have since parted company.
 */
export function RapportPanel({
  reports,
  timeEntries,
  materials,
  divergences,
  customers,
  canInvoice,
  siteUrl,
}: {
  reports: Report[];
  timeEntries: TimeEntry[];
  materials: MaterialLine[];
  divergences: Divergence[];
  customers: Customer[];
  canInvoice: boolean;
  siteUrl: string;
}) {
  const t = useTranslator();
  const [open, setOpen] = useState<Report | null>(null);

  const totalMinutes = timeEntries.reduce(
    (sum, e) => sum + (e.worked_minutes ?? 0),
    0
  );
  const materialTotal = materials.reduce(
    (sum, m) => sum + Math.round((m.quantity_milli * m.unit_price_rappen) / 1000),
    0
  );

  return (
    <div className="space-y-6">
      {divergences.length > 0 && (
        <section className="rounded-2xl border border-amber-200 bg-amber-50 p-4">
          <h2 className="text-sm font-bold text-amber-900">
            {t("rapport.divergence.title")}
          </h2>
          <p className="mt-1 text-xs text-amber-800">
            {t("rapport.divergence.intro")}
          </p>
          <ul className="mt-3 space-y-1.5">
            {divergences.map((d, i) => (
              <li key={`${d.report_id}-${i}`} className="text-xs text-amber-900">
                <span className="font-semibold">{d.number_text}</span>
                {": "}
                {d.source_was_voided
                  ? t("rapport.divergence.voided")
                  : t("rapport.divergence.changed", {
                      paper: hoursAndMinutes(d.minutes_on_paper),
                      now: hoursAndMinutes(d.minutes_now),
                    })}
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Stat label={t("rapport.stat.hours")} value={hoursAndMinutes(totalMinutes)} />
        <Stat label={t("rapport.stat.entries")} value={String(timeEntries.length)} />
        <Stat label={t("rapport.stat.material")} value={chf(materialTotal)} />
        <Stat label={t("rapport.stat.reports")} value={String(reports.length)} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-bold text-slate-900">
          {t("rapport.list.title")}
        </h2>
        {reports.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-6 text-center text-sm text-slate-500">
            {t("rapport.list.empty")}
          </div>
        ) : (
          <ul className="space-y-2">
            {reports.map((report) => (
              <li key={report.id}>
                <button
                  type="button"
                  onClick={() => setOpen(report)}
                  className="flex w-full items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 text-left shadow-sm transition-shadow hover:shadow-md"
                >
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold text-slate-900">
                      {report.number_text ?? t("rapport.status.draft")}
                    </p>
                    <p className="mt-0.5 truncate text-xs text-slate-500">
                      {report.title ?? "—"}
                      {report.signer_name ? ` · ${report.signer_name}` : ""}
                    </p>
                  </div>
                  {report.total_net_rappen != null && (
                    <span className="shrink-0 text-sm font-semibold text-slate-700">
                      {chf(report.total_net_rappen)}
                    </span>
                  )}
                  <StatusChip status={report.status} />
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      {open && (
        <ReportModal
          report={open}
          customers={customers}
          canInvoice={canInvoice}
          siteUrl={siteUrl}
          onClose={() => setOpen(null)}
        />
      )}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-3">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">
        {label}
      </p>
      <p className="mt-1 text-lg font-bold text-slate-900">{value}</p>
    </div>
  );
}

function StatusChip({ status }: { status: Report["status"] }) {
  const t = useTranslator();
  const styles: Record<string, string> = {
    draft: "bg-slate-100 text-slate-700",
    signed: "bg-emerald-100 text-emerald-800",
    sent: "bg-sky-100 text-sky-800",
    cancelled: "bg-red-100 text-red-800",
  };
  return (
    <span
      className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-semibold ${styles[status] ?? styles.draft}`}
    >
      {t(`rapport.status.${status}`)}
    </span>
  );
}

function ReportModal({
  report,
  customers,
  canInvoice,
  siteUrl,
  onClose,
}: {
  report: Report;
  customers: Customer[];
  canInvoice: boolean;
  siteUrl: string;
  onClose: () => void;
}) {
  const router = useRouter();
  const t = useTranslator();
  const [lines, setLines] = useState<ReportTimeLine[] | null>(null);
  const [materials, setMaterials] = useState<ReportMaterialLine[] | null>(null);
  const [link, setLink] = useState<string | null>(null);
  const [customerId, setCustomerId] = useState(customers[0]?.id ?? "");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      const supabase = createClient();
      const [{ data: l }, { data: m }] = await Promise.all([
        supabase.from("report_time_lines").select("*")
          .eq("report_id", report.id).order("performed_on"),
        supabase.from("report_material_lines").select("*")
          .eq("report_id", report.id).order("sort_order"),
      ]);
      if (cancelled) return;
      setLines(l ?? []);
      setMaterials(m ?? []);
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [report.id]);

  /** The token comes back exactly once and is not recoverable afterwards. */
  async function createLink() {
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { data, error: rpcError } = await supabase.rpc("create_document_link", {
      p_kind: "report",
      p_document_id: report.id,
      p_valid_days: 90,
    });
    setBusy(false);
    const row = Array.isArray(data) ? data[0] : null;
    if (rpcError || !row) {
      setError(rpcError?.message ?? t("rapport.link.failed"));
      return;
    }
    setLink(`${siteUrl}/r/${row.token}`);
  }

  async function createInvoice() {
    if (!customerId) return;
    setBusy(true);
    setError(null);
    const supabase = createClient();

    const { data: invoice, error: insertError } = await supabase
      .from("invoices")
      .insert({
        project_id: report.project_id,
        customer_id: customerId,
        report_id: report.id,
        // Derived from the project by the guard_invoice trigger before any
        // constraint or policy sees the row; the column is NOT NULL, so the
        // generated type demands a value the server is about to overwrite.
        company_id: report.company_id,
      })
      .select("id")
      .single();

    if (insertError || !invoice) {
      setBusy(false);
      setError(insertError?.message ?? t("rapport.invoice.failed"));
      return;
    }

    // One line per Rapport: the detail lives on the Rapport the customer
    // already signed, and restating it here would let the two disagree.
    const { error: lineError } = await supabase.from("invoice_lines").insert({
      invoice_id: invoice.id,
      description: report.title ?? `Rapport ${report.number_text}`,
      net_rappen: report.total_net_rappen ?? 0,
      quantity_milli: 1000,
    });
    if (lineError) {
      setBusy(false);
      setError(lineError.message);
      return;
    }

    const { error: issueError } = await supabase.rpc("issue_invoice", {
      p_invoice_id: invoice.id,
    });
    setBusy(false);
    if (issueError) {
      setError(issueError.message);
      return;
    }
    router.refresh();
    onClose();
  }

  const totalMinutes = (lines ?? []).reduce((s, l) => s + l.minutes, 0);

  return (
    <Modal
      title={report.number_text ?? t("rapport.status.draft")}
      onClose={onClose}
    >
      <div className="space-y-4">
        {report.signer_name && (
          <p className="text-sm text-slate-600">
            {t("rapport.signedBy", {
              name: report.signer_name,
              date: (report.signed_at ?? "").slice(0, 10),
            })}
          </p>
        )}

        {lines === null ? (
          <p className="text-sm text-slate-400">{t("rapport.loading")}</p>
        ) : (
          <>
            {lines.length > 0 && (
              <div>
                <h3 className="mb-1.5 text-xs font-bold uppercase tracking-wide text-slate-500">
                  {t("rapport.hours")} · {hoursAndMinutes(totalMinutes)}
                </h3>
                <ul className="divide-y divide-slate-100 text-sm">
                  {lines.map((l) => (
                    <li key={l.id} className="flex items-center gap-2 py-1.5">
                      <span className="w-24 shrink-0 text-slate-500">
                        {l.performed_on}
                      </span>
                      <span className="min-w-0 flex-1 truncate">
                        {l.performed_by_name ?? "—"}
                      </span>
                      <span className="font-medium">
                        {hoursAndMinutes(l.minutes)}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {(materials ?? []).length > 0 && (
              <div>
                <h3 className="mb-1.5 text-xs font-bold uppercase tracking-wide text-slate-500">
                  {t("rapport.material")}
                </h3>
                <ul className="divide-y divide-slate-100 text-sm">
                  {(materials ?? []).map((m) => (
                    <li key={m.id} className="flex items-center gap-2 py-1.5">
                      <span className="min-w-0 flex-1 truncate">
                        {m.description}
                      </span>
                      <span className="text-slate-500">
                        {quantity(m.quantity_milli)} {m.unit}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </>
        )}

        <ErrorNote message={error} />

        {report.status !== "draft" && (
          <div className="space-y-3 border-t border-slate-100 pt-4">
            {link ? (
              <div>
                <p className="mb-1 text-xs font-semibold text-slate-600">
                  {t("rapport.link.ready")}
                </p>
                <input
                  readOnly
                  value={link}
                  onFocus={(e) => e.currentTarget.select()}
                  className="w-full rounded-lg border border-slate-300 bg-slate-50 px-3 py-2 font-mono text-xs"
                />
                <p className="mt-1 text-xs text-slate-500">
                  {t("rapport.link.once")}
                </p>
              </div>
            ) : (
              <button
                type="button"
                onClick={createLink}
                disabled={busy}
                className={secondaryButtonClass}
              >
                {t("rapport.link.create")}
              </button>
            )}

            {canInvoice && (
              <div className="border-t border-slate-100 pt-3">
                {customers.length === 0 ? (
                  <p className="text-xs text-amber-700">
                    {t("rapport.invoice.needCustomer")}
                  </p>
                ) : (
                  <div className="flex flex-wrap items-end gap-2">
                    <div className="min-w-40 flex-1">
                      <label
                        htmlFor="inv-customer"
                        className="mb-1 block text-xs font-semibold text-slate-600"
                      >
                        {t("rapport.invoice.customer")}
                      </label>
                      <select
                        id="inv-customer"
                        value={customerId}
                        onChange={(e) => setCustomerId(e.target.value)}
                        className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
                      >
                        {customers.map((c) => (
                          <option key={c.id} value={c.id}>
                            {c.name}
                          </option>
                        ))}
                      </select>
                    </div>
                    <button
                      type="button"
                      onClick={createInvoice}
                      disabled={busy || !customerId}
                      className={primaryButtonClass}
                    >
                      {busy
                        ? t("rapport.invoice.creating")
                        : t("rapport.invoice.create")}
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </Modal>
  );
}
