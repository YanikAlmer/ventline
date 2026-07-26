"use client";

import { useState } from "react";

import {
  ErrorNote,
  inputClass,
  labelClass,
  primaryButtonClass,
} from "@/components/form";
import { useTranslator } from "@/i18n/client";
import { decimal, downloadCsv, toCsv } from "@/lib/csv";
import { createClient } from "@/lib/supabase/client";

type Row = {
  rechnungsnummer: string | null;
  rechnungsdatum: string | null;
  faelligkeit: string | null;
  status: string | null;
  kunde: string | null;
  kunde_plz: string | null;
  kunde_ort: string | null;
  kunde_land: string | null;
  kunde_id: string | null;
  bexio_kontakt_id: number | null;
  projekt: string | null;
  rapport: string | null;
  referenz_typ: string | null;
  referenz: string | null;
  waehrung: string | null;
  mwst_satz: number | null;
  netto: number | null;
  mwst: number | null;
  brutto: number | null;
  bezahlt_am: string | null;
  mwst_verfahren: string | null;
};

/**
 * The column order is the file's contract: an accountant who has built a
 * mapping once should not have it break because a column moved. Kept next to
 * the header labels rather than derived from the row object, whose key order
 * is an implementation detail of the driver.
 */
const COLUMNS = [
  "rechnungsnummer",
  "rechnungsdatum",
  "faelligkeit",
  "status",
  "kunde",
  "kunde_plz",
  "kunde_ort",
  "kunde_land",
  "kunde_id",
  "bexio_kontakt_id",
  "projekt",
  "rapport",
  "referenz_typ",
  "referenz",
  "waehrung",
  "mwst_satz",
  "netto",
  "mwst",
  "brutto",
  "bezahlt_am",
  "mwst_verfahren",
] as const satisfies readonly (keyof Row)[];

const MONEY = new Set(["mwst_satz", "netto", "mwst", "brutto"]);

function iso(date: Date): string {
  // Local calendar date, not UTC: toISOString() in Zurich turns 1 January
  // into 31 December for anyone who opens the page before 01:00.
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${
    String(date.getDate()).padStart(2, "0")
  }`;
}

/** MWST is filed by quarter, so the quarter is what the presets offer. */
function quarterRange(offset: number): { from: string; to: string } {
  const now = new Date();
  const q = Math.floor(now.getMonth() / 3) + offset;
  const year = now.getFullYear() + Math.floor(q / 4);
  const quarter = ((q % 4) + 4) % 4;
  return {
    from: iso(new Date(year, quarter * 3, 1)),
    to: iso(new Date(year, quarter * 3 + 3, 0)),
  };
}

export function ExportPanel() {
  const t = useTranslator();
  const initial = quarterRange(0);
  const [from, setFrom] = useState(initial.from);
  const [to, setTo] = useState(initial.to);
  const [rows, setRows] = useState<Row[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function load() {
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { data, error: rpcError } = await supabase.rpc("invoice_export", {
      p_from: from,
      p_to: to,
    });
    setBusy(false);
    if (rpcError) {
      setError(rpcError.message);
      setRows(null);
      return;
    }
    setRows((data ?? []) as Row[]);
  }

  function download() {
    if (!rows) return;
    const csv = toCsv(
      COLUMNS,
      rows.map((row) =>
        COLUMNS.map((column) =>
          MONEY.has(column) ? decimal(row[column] as number) : row[column],
        ),
      ),
    );
    downloadCsv(`ventline-rechnungen-${from}-${to}.csv`, csv);
  }

  const num = (value: number | null) => Number(value ?? 0);
  const totals = (rows ?? []).reduce(
    (acc, row) => ({
      netto: acc.netto + num(row.netto),
      mwst: acc.mwst + num(row.mwst),
      brutto: acc.brutto + num(row.brutto),
    }),
    { netto: 0, mwst: 0, brutto: 0 },
  );

  // The recapitulation the accountant is actually here for: one total per
  // rate, which is the shape the MWST return asks for.
  const byRate = new Map<number, { netto: number; mwst: number }>();
  for (const row of rows ?? []) {
    const rate = num(row.mwst_satz);
    const group = byRate.get(rate) ?? { netto: 0, mwst: 0 };
    group.netto += num(row.netto);
    group.mwst += num(row.mwst);
    byRate.set(rate, group);
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl font-black tracking-tight text-slate-900">
          {t("export.title")}
        </h1>
        <p className="mt-1 text-sm text-slate-500">{t("export.intro")}</p>
      </div>

      <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
        <div className="flex flex-wrap items-end gap-3">
          <div>
            <label className={labelClass} htmlFor="export-from">
              {t("export.from")}
            </label>
            <input
              id="export-from"
              type="date"
              value={from}
              onChange={(event) => setFrom(event.target.value)}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass} htmlFor="export-to">
              {t("export.to")}
            </label>
            <input
              id="export-to"
              type="date"
              value={to}
              onChange={(event) => setTo(event.target.value)}
              className={inputClass}
            />
          </div>
          <button
            type="button"
            onClick={load}
            disabled={busy}
            className={primaryButtonClass}
          >
            {busy ? t("export.loading") : t("export.load")}
          </button>
        </div>

        <div className="mt-3 flex flex-wrap gap-2">
          {([
            { key: "export.thisQuarter", offset: 0 },
            { key: "export.lastQuarter", offset: -1 },
          ] as const).map((preset) => (
            <button
              key={preset.key}
              type="button"
              onClick={() => {
                const range = quarterRange(preset.offset);
                setFrom(range.from);
                setTo(range.to);
                setRows(null);
              }}
              className="rounded-full border border-slate-300 px-3 py-1 text-xs font-semibold text-slate-600 hover:bg-slate-50"
            >
              {t(preset.key)}
            </button>
          ))}
          <button
            type="button"
            onClick={() => {
              const now = new Date();
              setFrom(iso(new Date(now.getFullYear(), 0, 1)));
              setTo(iso(now));
              setRows(null);
            }}
            className="rounded-full border border-slate-300 px-3 py-1 text-xs font-semibold text-slate-600 hover:bg-slate-50"
          >
            {t("export.yearToDate")}
          </button>
        </div>
      </div>

      <ErrorNote message={error} />

      {rows !== null && (
        <div className="space-y-4">
          {rows.length === 0 ? (
            <p className="rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center text-sm text-slate-500">
              {t("export.empty")}
            </p>
          ) : (
            <>
              <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
                <h2 className="mb-2 text-xs font-bold uppercase tracking-wide text-slate-500">
                  {t("export.recap")}
                </h2>
                {/* Four labelled columns, not three unlabelled ones. The
                    per-rate rows and the total row have to mean the same thing
                    in the same position, or the reader silently reads a gross
                    figure as a tax figure. */}
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-xs uppercase tracking-wide text-slate-400">
                      <th className="pb-1 text-left font-semibold">
                        {t("export.rateColumn")}
                      </th>
                      <th className="pb-1 text-right font-semibold">
                        {t("export.net")}
                      </th>
                      <th className="pb-1 text-right font-semibold">
                        {t("export.vat")}
                      </th>
                      <th className="pb-1 text-right font-semibold">
                        {t("export.gross")}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {[...byRate.entries()]
                      .sort((a, b) => a[0] - b[0])
                      .map(([rate, group]) => (
                        <tr key={rate} className="border-t border-slate-100">
                          <td className="py-1.5 text-slate-600">
                            {rate.toFixed(1)}%
                          </td>
                          <td className="py-1.5 text-right tabular-nums text-slate-600">
                            {group.netto.toFixed(2)}
                          </td>
                          <td className="py-1.5 text-right tabular-nums text-slate-600">
                            {group.mwst.toFixed(2)}
                          </td>
                          <td className="py-1.5 text-right tabular-nums text-slate-600">
                            {(group.netto + group.mwst).toFixed(2)}
                          </td>
                        </tr>
                      ))}
                    <tr className="border-t-2 border-slate-200">
                      <td className="pt-2 font-bold text-slate-900">
                        {t("export.total")}
                      </td>
                      <td className="pt-2 text-right tabular-nums font-bold text-slate-900">
                        {totals.netto.toFixed(2)}
                      </td>
                      <td className="pt-2 text-right tabular-nums font-bold text-slate-900">
                        {totals.mwst.toFixed(2)}
                      </td>
                      <td className="pt-2 text-right tabular-nums font-bold text-slate-900">
                        {totals.brutto.toFixed(2)}
                      </td>
                    </tr>
                  </tbody>
                </table>
                <p className="mt-2 text-xs text-slate-400">
                  {t("export.rowNote", { count: String(rows.length) })}
                </p>
              </div>

              <button
                type="button"
                onClick={download}
                className={primaryButtonClass}
              >
                ⤓ {t("export.download")}
              </button>

              <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
                <table className="w-full text-xs">
                  <thead className="bg-slate-50 text-left text-slate-500">
                    <tr>
                      {["rechnungsnummer", "rechnungsdatum", "kunde", "mwst_satz", "netto", "mwst", "brutto", "status"].map(
                        (column) => (
                          <th key={column} className="whitespace-nowrap px-3 py-2 font-semibold">
                            {column}
                          </th>
                        ),
                      )}
                    </tr>
                  </thead>
                  <tbody>
                    {rows.slice(0, 25).map((row, index) => (
                      <tr
                        key={`${row.rechnungsnummer}-${row.mwst_satz}-${index}`}
                        className="border-t border-slate-100"
                      >
                        <td className="whitespace-nowrap px-3 py-1.5 font-semibold text-slate-900">
                          {row.rechnungsnummer}
                        </td>
                        <td className="whitespace-nowrap px-3 py-1.5 text-slate-600">
                          {row.rechnungsdatum}
                        </td>
                        <td className="max-w-40 truncate px-3 py-1.5 text-slate-600">
                          {row.kunde}
                        </td>
                        <td className="px-3 py-1.5 text-right tabular-nums text-slate-600">
                          {decimal(row.mwst_satz)}
                        </td>
                        <td className="px-3 py-1.5 text-right tabular-nums text-slate-600">
                          {decimal(row.netto)}
                        </td>
                        <td className="px-3 py-1.5 text-right tabular-nums text-slate-600">
                          {decimal(row.mwst)}
                        </td>
                        <td className="px-3 py-1.5 text-right tabular-nums font-semibold text-slate-900">
                          {decimal(row.brutto)}
                        </td>
                        <td className="px-3 py-1.5 text-slate-500">{row.status}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {rows.length > 25 && (
                  <p className="border-t border-slate-100 px-3 py-2 text-xs text-slate-400">
                    {t("export.previewNote", { count: String(rows.length - 25) })}
                  </p>
                )}
              </div>
            </>
          )}
        </div>
      )}

      <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
        <h2 className="text-xs font-bold uppercase tracking-wide text-slate-500">
          {t("export.bexioTitle")}
        </h2>
        <p className="mt-1 text-sm text-slate-600">{t("export.bexioNote")}</p>
      </div>
    </div>
  );
}
