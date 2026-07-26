import type { Tables } from "@/lib/database.types";
import type { ServerClient } from "@/lib/supabase/server";

export type TimeEntry = Tables<"time_entries">;
export type MaterialLine = Tables<"material_lines">;
export type Report = Tables<"reports">;
export type ReportTimeLine = Tables<"report_time_lines">;
export type ReportMaterialLine = Tables<"report_material_lines">;
export type Invoice = Tables<"invoices">;
export type InvoiceLine = Tables<"invoice_lines">;
export type InvoiceTaxGroup = Tables<"invoice_tax_groups">;
export type Customer = Tables<"customers">;

/** Integer Rappen to "1'234.55" — Swiss grouping uses an apostrophe. */
export function chf(rappen: number | null | undefined): string {
  if (rappen == null) return "—";
  return (rappen / 100)
    .toFixed(2)
    .replace(/\B(?=(\d{3})+(?!\d))/g, "’");
}

/** "7 h 15" reads like a Rapport; "435 minutes" does not. */
export function hoursAndMinutes(minutes: number | null | undefined): string {
  if (minutes == null) return "—";
  return minutes % 60 === 0
    ? `${minutes / 60} h`
    : `${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, "0")}`;
}

/** Integer thousandths to a human quantity: 2500 → "2.5", 3000 → "3". */
export function quantity(milli: number): string {
  return milli % 1000 === 0
    ? String(milli / 1000)
    : String(milli / 1000);
}

export async function getProjectTime(
  supabase: ServerClient,
  projectId: string
): Promise<TimeEntry[]> {
  const { data } = await supabase
    .from("time_entries")
    .select("*")
    .eq("project_id", projectId)
    .is("voided_at", null)
    .order("work_date", { ascending: false })
    .limit(300);
  return data ?? [];
}

export async function getProjectMaterials(
  supabase: ServerClient,
  projectId: string
): Promise<MaterialLine[]> {
  const { data } = await supabase
    .from("material_lines")
    .select("*")
    .eq("project_id", projectId)
    .order("created_at", { ascending: false });
  return data ?? [];
}

export async function getProjectReports(
  supabase: ServerClient,
  projectId: string
): Promise<Report[]> {
  const { data } = await supabase
    .from("reports")
    .select("*")
    .eq("project_id", projectId)
    .order("created_at", { ascending: false });
  return data ?? [];
}

/**
 * Rapporte whose source hours have since been corrected. This is the office
 * work item that reconciles "the signed document must not change" with "the
 * underlying time record may legitimately need to" — the view exists precisely
 * so the difference surfaces as a conversation rather than as silent drift.
 */
export async function getDivergences(supabase: ServerClient) {
  const { data } = await supabase.from("report_divergences").select("*");
  return data ?? [];
}
