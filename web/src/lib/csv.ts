/**
 * CSV for a Swiss Treuhänder, which is to say: CSV that opens correctly in a
 * de-CH copy of Excel on the first try.
 *
 * Every choice here is a specific failure someone has already had:
 *
 *  - **Semicolon, not comma.** Excel splits on the locale's list separator,
 *    which in de-CH is `;`. A comma-delimited file opens as a single column
 *    of garbage, and the person receiving it concludes the software is broken.
 *
 *  - **UTF-8 with a BOM.** Without it Excel on Windows decodes the file as
 *    the ANSI code page and every Umlaut turns to mojibake — Zürich becomes
 *    ZÃ¼rich. The BOM is three bytes and removes the entire class of bug.
 *
 *  - **CRLF line endings**, per RFC 4180.
 *
 *  - **A dot for the decimal separator.** This is the one that looks wrong
 *    to German eyes and is right here: Switzerland writes 1'234.50, not
 *    1.234,50. Combined with `;` there is no ambiguity for Excel to resolve.
 *
 *  - **No thousands separator.** An apostrophe is correct Swiss typography
 *    and is not a number to any importer.
 */

const DELIMITER = ";";
const NEWLINE = "\r\n";
const BOM = "﻿";

/** RFC 4180: quote only when needed, and double any embedded quote. */
function escapeField(value: unknown): string {
  if (value === null || value === undefined) return "";

  // Numbers are formatted by the caller, which knows how many decimals the
  // column means. Anything reaching here as a number gets a plain rendering
  // rather than a locale-aware one, which would reintroduce the separator
  // problem this module exists to avoid.
  const text = typeof value === "number" ? String(value) : String(value);

  return /[";\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

export function toCsv(
  headers: readonly string[],
  rows: readonly (readonly unknown[])[],
): string {
  const lines = [headers, ...rows].map((row) =>
    row.map(escapeField).join(DELIMITER),
  );
  // No trailing newline: some importers read one as a final empty record.
  return BOM + lines.join(NEWLINE);
}

/** Money and rates, fixed to two decimals so columns line up when summed. */
export function decimal(value: number | string | null | undefined): string {
  if (value === null || value === undefined || value === "") return "";
  const n = typeof value === "string" ? Number(value) : value;
  return Number.isFinite(n) ? n.toFixed(2) : "";
}

export function downloadCsv(filename: string, content: string) {
  // "text/csv;charset=utf-8" rather than a bare text/csv: Safari has been
  // known to re-encode when the charset is unstated, which would undo the BOM.
  const blob = new Blob([content], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}
