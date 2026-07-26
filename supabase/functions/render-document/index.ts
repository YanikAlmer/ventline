// Renders a signed Rapport to PDF, and — for an issued invoice — appends the
// Swiss QR-bill payment part on its own page.
//
// The division of labour is the same one the magic-link flow uses: **Postgres
// decides, the function draws.** The database has already assigned the number,
// frozen the content, minted the reference and built the 31-line payload; this
// function reads that and turns it into paper. It invents nothing, because
// anything it invented could disagree with the document that was signed.
//
// Invoked with the service role, so it can read private storage and write the
// documents bucket. Never called directly by a client.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { PDFDocument, rgb } from "npm:pdf-lib@1.17.1";
import fontkit from "npm:@pdf-lib/fontkit@1.1.1";
import { encodeQR } from "jsr:@paulmillr/qr@0.6.0";
import { liberationSansBold, liberationSansRegular } from "./fonts.ts";
import {
  drawQrBill,
  formatAmount,
  GEO,
  mm,
  type Address,
  type Lang,
} from "./qrbill.ts";

const A4 = { w: mm(210), h: mm(297) };
const MARGIN = mm(20);

/** Photos are downscaled client-side; this bounds a runaway Rapport anyway. */
const MAX_PHOTOS = 20;

type Json = Record<string, unknown>;

function chf(rappen: number): string {
  return `CHF ${formatAmount(rappen)}`;
}

function minutesLabel(minutes: number): string {
  return minutes % 60 === 0
    ? `${minutes / 60} h`
    : `${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, "0")}`;
}

async function loadFonts(doc: PDFDocument) {
  doc.registerFontkit(fontkit);
  // Liberation Sans, not a Standard-14 face. Helvetica in pdf-lib is
  // WinAnsi-encoded and throws on Latin Extended A — which SIX explicitly
  // permits in names — so a Polish or Czech customer would break the render.
  //
  // Inlined as base64 rather than read from disk: the management API accepts
  // text files only, and bundling the binaries would tie every deploy to the
  // CLI. See scripts/build-fonts.py.
  return {
    regular: await doc.embedFont(liberationSansRegular(), { subset: true }),
    bold: await doc.embedFont(liberationSansBold(), { subset: true }),
  };
}

/**
 * @paulmillr/qr rejects border: 0, so a one-module border is requested and
 * stripped here. The quiet zone is laid out by the renderer as 5 mm of clear
 * space around the 46 mm symbol; baking modules into the matrix would shrink
 * the symbol below its mandated size.
 */
function qrMatrix(payload: string): boolean[][] {
  const withBorder = encodeQR(payload, "raw", { ecc: "medium", border: 1 });
  return withBorder.slice(1, -1).map((row) => row.slice(1, -1));
}

export async function renderRapport(
  report: Json,
  lines: Json[],
  materials: Json[],
  company: Json,
  photos: Uint8Array[],
  signature?: Uint8Array | null,
): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  const fonts = await loadFonts(doc);
  let page = doc.addPage([A4.w, A4.h]);
  let y = A4.h - MARGIN;

  const text = (
    s: string,
    size: number,
    bold = false,
    indent = 0,
    color = rgb(0, 0, 0),
  ) => {
    page.drawText(s, {
      x: MARGIN + indent,
      y,
      size,
      font: bold ? fonts.bold : fonts.regular,
      color,
    });
  };

  const newPageIfNeeded = (needed: number) => {
    if (y - needed < MARGIN) {
      page = doc.addPage([A4.w, A4.h]);
      y = A4.h - MARGIN;
    }
  };

  text(String(company.name ?? ""), 10, true);
  y -= 24;
  text(`Rapport ${report.number_text ?? ""}`, 18, true);
  y -= 20;
  if (report.title) {
    text(String(report.title), 12);
    y -= 16;
  }
  if (report.signed_at) {
    text(String(report.signed_at).slice(0, 10), 9, false, 0, rgb(0.4, 0.4, 0.4));
    y -= 18;
  }

  if (report.summary) {
    y -= 6;
    for (const line of String(report.summary).split("\n")) {
      newPageIfNeeded(14);
      text(line, 10);
      y -= 13;
    }
  }

  if (lines.length > 0) {
    y -= 14;
    newPageIfNeeded(40);
    text("Arbeitszeit", 11, true);
    y -= 16;
    let totalMinutes = 0;
    for (const l of lines) {
      newPageIfNeeded(14);
      const minutes = Number(l.minutes ?? 0);
      totalMinutes += minutes;
      text(String(l.performed_on ?? ""), 9);
      text(String(l.performed_by_name ?? ""), 9, false, 70);
      text(String(l.description ?? ""), 9, false, 190);
      page.drawText(minutesLabel(minutes), {
        x: A4.w - MARGIN - fonts.regular.widthOfTextAtSize(minutesLabel(minutes), 9),
        y,
        size: 9,
        font: fonts.regular,
      });
      y -= 13;
    }
    y -= 4;
    newPageIfNeeded(16);
    text("Total", 10, true);
    page.drawText(minutesLabel(totalMinutes), {
      x: A4.w - MARGIN - fonts.bold.widthOfTextAtSize(minutesLabel(totalMinutes), 10),
      y,
      size: 10,
      font: fonts.bold,
    });
    y -= 16;
  }

  if (materials.length > 0) {
    y -= 10;
    newPageIfNeeded(40);
    text("Material", 11, true);
    y -= 16;
    for (const m of materials) {
      newPageIfNeeded(14);
      const qty = Number(m.quantity_milli ?? 0) / 1000;
      text(String(m.description ?? ""), 9);
      const q = `${qty} ${m.unit ?? ""}`;
      page.drawText(q, {
        x: A4.w - MARGIN - fonts.regular.widthOfTextAtSize(q, 9),
        y,
        size: 9,
        font: fonts.regular,
      });
      y -= 13;
    }
  }

  for (const bytes of photos.slice(0, MAX_PHOTOS)) {
    try {
      const img = await doc.embedJpg(bytes);
      const scale = Math.min((A4.w - 2 * MARGIN) / img.width, 240 / img.height);
      newPageIfNeeded(img.height * scale + 20);
      page.drawImage(img, {
        x: MARGIN,
        y: y - img.height * scale,
        width: img.width * scale,
        height: img.height * scale,
      });
      y -= img.height * scale + 14;
    } catch {
      // A photo that will not decode must not sink the whole document.
    }
  }

  // Signature block. The drawn signature is the point of the document, so it
  // goes on the page — a name under a rule proves nothing the database did not
  // already know.
  y -= 20;
  newPageIfNeeded(120);
  if (signature) {
    try {
      const img = await doc.embedPng(signature);
      const scale = Math.min(mm(60) / img.width, mm(22) / img.height);
      page.drawImage(img, {
        x: MARGIN,
        y: y - img.height * scale + 4,
        width: img.width * scale,
        height: img.height * scale,
      });
      y -= img.height * scale + 2;
    } catch {
      // A signature that will not decode must not sink the document; the name
      // and timestamp below still stand on their own.
    }
  }
  page.drawLine({
    start: { x: MARGIN, y },
    end: { x: MARGIN + mm(70), y },
    thickness: 0.5,
    color: rgb(0.6, 0.6, 0.6),
  });
  y -= 12;
  text(String(report.signer_name ?? ""), 10, true);
  y -= 12;
  text("Unterschrift Kunde", 8, false, 0, rgb(0.4, 0.4, 0.4));
  y -= 24;

  // The content hash, printed. A free external anchor: the customer's own copy
  // carries the fingerprint of what they signed, so neither side can later
  // substitute a different document and claim it is the same one.
  if (report.content_hash_hex) {
    // Printed on the customer's own copy: a free external anchor, so neither
    // side can later substitute a different document and call it the same one.
    text(`SHA-256: ${report.content_hash_hex}`, 6, false, 0, rgb(0.5, 0.5, 0.5));
  }

  return await doc.save();
}

export async function renderInvoice(
  invoice: Json,
  lines: Json[],
  taxGroups: Json[],
  company: Json,
): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  const fonts = await loadFonts(doc);
  const page = doc.addPage([A4.w, A4.h]);
  let y = A4.h - MARGIN;

  const text = (s: string, size: number, bold = false, indent = 0) =>
    page.drawText(s, {
      x: MARGIN + indent,
      y,
      size,
      font: bold ? fonts.bold : fonts.regular,
    });

  text(String(invoice.creditor_name ?? company.name ?? ""), 11, true);
  y -= 14;
  for (
    const l of [
      [invoice.creditor_street, invoice.creditor_building_no].filter(Boolean).join(" "),
      [invoice.creditor_post_code, invoice.creditor_town].filter(Boolean).join(" "),
    ].filter(Boolean)
  ) {
    text(String(l), 9);
    y -= 12;
  }
  if (invoice.creditor_uid_digits) {
    const uid = String(invoice.creditor_uid_digits);
    text(`CHE-${uid.slice(0, 3)}.${uid.slice(3, 6)}.${uid.slice(6, 9)} MWST`, 8);
    y -= 16;
  }

  y -= 20;
  text(String(invoice.debtor_name ?? ""), 10, true);
  y -= 13;
  for (
    const l of [
      [invoice.debtor_street, invoice.debtor_building_no].filter(Boolean).join(" "),
      [invoice.debtor_post_code, invoice.debtor_town].filter(Boolean).join(" "),
    ].filter(Boolean)
  ) {
    text(String(l), 10);
    y -= 13;
  }

  y -= 26;
  text(`Rechnung ${invoice.number_text ?? ""}`, 16, true);
  y -= 18;
  text(`Rechnungsdatum: ${invoice.invoice_date ?? ""}`, 9);
  y -= 12;
  text(`Zahlbar bis: ${invoice.due_date ?? ""}`, 9);
  y -= 24;

  for (const l of lines) {
    text(String(l.description ?? ""), 9);
    const net = chf(Number(l.net_rappen ?? 0));
    page.drawText(net, {
      x: A4.w - MARGIN - fonts.regular.widthOfTextAtSize(net, 9),
      y,
      size: 9,
      font: fonts.regular,
    });
    y -= 13;
  }

  y -= 8;
  page.drawLine({
    start: { x: MARGIN, y: y + 6 },
    end: { x: A4.w - MARGIN, y: y + 6 },
    thickness: 0.5,
    color: rgb(0.7, 0.7, 0.7),
  });

  const row = (label: string, value: string, bold = false) => {
    page.drawText(label, {
      x: MARGIN, y, size: 9, font: bold ? fonts.bold : fonts.regular,
    });
    page.drawText(value, {
      x: A4.w - MARGIN -
        (bold ? fonts.bold : fonts.regular).widthOfTextAtSize(value, 9),
      y, size: 9, font: bold ? fonts.bold : fonts.regular,
    });
    y -= 13;
  };

  row("Total netto", chf(Number(invoice.total_net_rappen ?? 0)));
  // The Art. 26 recapitulation: one line per rate, never a single blended
  // figure. An unregistered business has no groups and therefore no tax block.
  for (const g of taxGroups) {
    const rate = Number(g.rate_bp ?? 0) / 100;
    row(`MWST ${rate.toFixed(1)}%`, chf(Number(g.tax_rappen ?? 0)));
  }
  row("Total", chf(Number(invoice.total_gross_rappen ?? 0)), true);

  // The payment part occupies the bottom 105 mm of its own page, so a long
  // invoice can never push it off the sheet.
  const billPage = doc.addPage([A4.w, A4.h]);
  drawQrBill(
    billPage,
    fonts,
    {
      lang: (String(invoice.lang ?? "de") as Lang),
      iban: String(invoice.creditor_iban ?? ""),
      creditor: {
        name: String(invoice.creditor_name ?? ""),
        street: invoice.creditor_street as string | null,
        buildingNo: invoice.creditor_building_no as string | null,
        postCode: invoice.creditor_post_code as string | null,
        town: invoice.creditor_town as string | null,
        country: invoice.creditor_country as string | null,
      },
      debtor: invoice.debtor_name
        ? ({
          name: String(invoice.debtor_name),
          street: invoice.debtor_street as string | null,
          buildingNo: invoice.debtor_building_no as string | null,
          postCode: invoice.debtor_post_code as string | null,
          town: invoice.debtor_town as string | null,
          country: invoice.debtor_country as string | null,
        } as Address)
        : null,
      currency: String(invoice.currency ?? "CHF"),
      amountRappen: Number(invoice.total_gross_rappen ?? 0),
      referenceType: String(invoice.reference_type ?? "NON") as
        "QRR" | "SCOR" | "NON",
      reference: invoice.reference as string | null,
      message: `Rechnung ${invoice.number_text ?? ""}`,
      payload: String(invoice.qr_payload ?? ""),
    },
    qrMatrix(String(invoice.qr_payload ?? "")),
  );

  return await doc.save();
}

Deno.serve(async (req: Request) => {
  const secret = Deno.env.get("RENDER_SECRET");
  if (secret && req.headers.get("x-ventline-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }

  let body: { kind?: string; id?: string };
  try {
    body = await req.json();
  } catch {
    return new Response("bad request", { status: 400 });
  }
  const { kind, id } = body;
  if (!id || (kind !== "report" && kind !== "invoice")) {
    return new Response("bad request", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    let pdf: Uint8Array;
    let path: string;

    // Every read goes through a SECURITY DEFINER RPC. service_role has no
    // table grants in this schema by design, so this function can fetch one
    // document's render inputs and nothing else — the same shape open-document
    // already uses for magic links.
    if (kind === "report") {
      const { data, error } = await supabase
        .rpc("report_render_payload", { p_report_id: id });
      if (error) throw error;
      if (!data) {
        return Response.json({ ok: false, reason: "not_renderable" }, { status: 409 });
      }

      const photos: Uint8Array[] = [];
      for (const ref of (data.photos ?? []).slice(0, MAX_PHOTOS)) {
        const { data: blob } = await supabase.storage
          .from(String(ref.bucket)).download(String(ref.path));
        if (blob) photos.push(new Uint8Array(await blob.arrayBuffer()));
      }

      // The signature lives in its own private bucket, separate from jobsite
      // media, so it is fetched by path rather than arriving with the photos.
      let signature: Uint8Array | null = null;
      if (data.report?.signature_path) {
        const { data: sigBlob } = await supabase.storage
          .from("signatures").download(String(data.report.signature_path));
        if (sigBlob) signature = new Uint8Array(await sigBlob.arrayBuffer());
      }

      pdf = await renderRapport(
        data.report, data.time_lines ?? [], data.material_lines ?? [],
        data.company ?? {}, photos, signature,
      );
      path = `${data.report.company_id}/rapport-${data.report.number_text}.pdf`;
    } else {
      const { data, error } = await supabase
        .rpc("invoice_render_payload", { p_invoice_id: id });
      if (error) throw error;
      if (!data) {
        return Response.json({ ok: false, reason: "not_renderable" }, { status: 409 });
      }

      pdf = await renderInvoice(
        data.invoice, data.lines ?? [], data.tax_groups ?? [], data.company ?? {},
      );
      path = `${data.invoice.company_id}/rechnung-${data.invoice.number_text}.pdf`;
    }

    const { error: upErr } = await supabase.storage
      .from("documents")
      .upload(path, pdf, { contentType: "application/pdf", upsert: true });
    if (upErr) throw upErr;

    const digest = await crypto.subtle.digest(
      "SHA-256",
      pdf.slice() as unknown as ArrayBuffer,
    );
    const sha = [...new Uint8Array(digest)]
      .map((b) => b.toString(16).padStart(2, "0")).join("");

    const { error: recErr } = await supabase
      .rpc("record_rendered_pdf", {
        p_kind: kind, p_id: id, p_path: path, p_sha256: sha,
      });
    if (recErr) throw recErr;

    return Response.json({ ok: true, path, bytes: pdf.length, sha256: sha });
  } catch (error) {
    // Supabase errors are plain objects, not Errors: String(error) yields
    // "[object Object]", which is the least useful thing possible at exactly
    // the moment something is wrong.
    const detail = error instanceof Error
      ? error.message
      : typeof error === "object" && error !== null
      ? JSON.stringify(error)
      : String(error);
    return Response.json({ ok: false, error: detail }, { status: 500 });
  }
});
