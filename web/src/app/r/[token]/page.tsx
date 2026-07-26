import type { Metadata } from "next";

import { getTranslator } from "@/i18n/server";
import { chf } from "@/lib/rapport";

// A customer opening a link they were sent. No account, no session, and
// deliberately no indexing: these URLs are bearer credentials.
export const metadata: Metadata = {
  robots: { index: false, follow: false },
};

type Resolved = {
  ok: boolean;
  kind?: "report" | "invoice";
  company_name?: string;
  number?: string;
  signed_at?: string;
  signer_name?: string;
  project_name?: string;
  summary?: string;
  invoice_date?: string;
  due_date?: string;
  total_gross_rappen?: number;
  currency?: string;
  pdf_url?: string | null;
};

async function resolve(token: string): Promise<Resolved> {
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) return { ok: false };
  try {
    // The anon key only gets us to the function; the function holds the
    // service role and is the only thing that can resolve the token.
    const res = await fetch(`${base}/functions/v1/open-document`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? ""}`,
      },
      body: JSON.stringify({ token }),
      cache: "no-store",
    });
    if (!res.ok) return { ok: false };
    return (await res.json()) as Resolved;
  } catch {
    return { ok: false };
  }
}

export default async function DocumentLinkPage(props: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await props.params;
  const t = await getTranslator();
  const doc = await resolve(token);

  if (!doc.ok) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center px-6 py-12">
        <div className="rounded-2xl border border-slate-200 bg-white p-8 text-center shadow-sm">
          <p className="text-4xl">🔒</p>
          <h1 className="mt-4 text-lg font-bold text-slate-900">
            {t("link.expired.title")}
          </h1>
          <p className="mt-2 text-sm text-slate-500">
            {t("link.expired.body")}
          </p>
        </div>
      </main>
    );
  }

  const isInvoice = doc.kind === "invoice";

  return (
    <main className="mx-auto max-w-md px-6 py-12">
      <p className="text-sm font-semibold text-slate-500">{doc.company_name}</p>
      <h1 className="mt-1 text-2xl font-black tracking-tight text-slate-900">
        {isInvoice ? t("link.invoice.title") : t("link.report.title")}{" "}
        {doc.number}
      </h1>

      <div className="mt-6 space-y-3 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        {doc.project_name && (
          <Row label={t("link.project")} value={doc.project_name} />
        )}
        {doc.summary && <p className="text-sm text-slate-600">{doc.summary}</p>}
        {doc.signed_at && (
          <Row
            label={t("link.signed")}
            value={`${doc.signer_name ?? ""} · ${doc.signed_at.slice(0, 10)}`}
          />
        )}
        {isInvoice && (
          <>
            <Row label={t("link.invoiceDate")} value={doc.invoice_date ?? "—"} />
            <Row label={t("link.dueDate")} value={doc.due_date ?? "—"} />
            <Row
              label={t("link.total")}
              value={`${doc.currency ?? "CHF"} ${chf(doc.total_gross_rappen ?? 0)}`}
            />
          </>
        )}
      </div>

      {doc.pdf_url ? (
        <a
          href={doc.pdf_url}
          className="mt-6 flex min-h-12 w-full items-center justify-center rounded-xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white hover:bg-slate-700"
        >
          {t("link.openPdf")}
        </a>
      ) : (
        <p className="mt-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          {t("link.pdfPending")}
        </p>
      )}
    </main>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 text-sm">
      <span className="text-slate-500">{label}</span>
      <span className="font-semibold text-slate-900">{value}</span>
    </div>
  );
}
