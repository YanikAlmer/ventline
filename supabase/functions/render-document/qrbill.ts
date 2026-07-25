// The Swiss QR-bill payment part, drawn to the SIX Style Guide QR-bill v1.1
// (effective 01.01.2026), the companion geometry document to Implementation
// Guidelines v2.3.
//
// Every constant here is from that document. The two that are most often got
// wrong, stated once:
//
//  1. The 46 x 46 mm QR size **excludes** the quiet zone. The quiet zone is an
//     additional 5 mm on every side, so 56 x 56 mm must be kept clear.
//  2. There are **no fixed y positions** for the individual text blocks. The
//     Style Guide is explicit: "Because there is no fixed position for the
//     individual text blocks, if any are omitted the rest all move up." So the
//     information block is a top-anchored flow, not a coordinate table. Only
//     the section rectangles below are fixed.

import { PDFDocument, PDFFont, PDFPage, rgb } from "npm:pdf-lib@1.17.1";

/** Millimetres to PDF points. */
export const mm = (v: number) => (v * 72) / 25.4;

// ---------------------------------------------------------------- geometry
// Origins: A4 = top-left of the page; PP = top-left of the payment part;
// RC = top-left of the receipt. All in millimetres.
export const GEO = {
  a4: { w: 210, h: 297 },
  /** The band sits on the lower edge of the page: 297 - 105. */
  bandY: 192,
  band: { w: 210, h: 105 },
  receipt: { x: 0, w: 62 },
  payment: { x: 62, w: 148 },
  margin: 5,

  // Payment part sections (PP-relative).
  pp: {
    title: { x: 5, y: 5, w: 51, h: 7 },
    /** Starts at the TOP margin, level with the title — not below it. */
    info: { x: 56, y: 5, w: 87, h: 85 },
    qr: { x: 5, y: 17, size: 46 },
    amount: { x: 5, y: 68, w: 51, h: 22 },
    further: { x: 5, y: 90, w: 138, h: 10 },
  },
  // Receipt sections (RC-relative). Its info block DOES start below the title.
  rc: {
    title: { x: 5, y: 5, w: 52, h: 7 },
    info: { x: 5, y: 12, w: 52, h: 56 },
    amount: { x: 5, y: 68, w: 52, h: 14 },
    acceptance: { x: 5, y: 82, w: 52, h: 18 },
  },

  /** Corner-mark boxes for fields left blank, from SIX's own asset filenames. */
  blank: {
    amountPP: { w: 40, h: 15 },
    payableByPP: { w: 65, h: 25 },
    amountRC: { w: 30, h: 10 },
    payableByRC: { w: 52, h: 20 },
    cornerMark: 3,
    strokePt: 0.75,
  },
} as const;

// Type sizes and leading, from Style Guide p.15.
export const TYPE = {
  ppTitle: { size: 11, bold: true, leading: 11 },
  ppHeading: { size: 8, bold: true, leading: 11 },
  ppValue: { size: 10, bold: false, leading: 11 },
  ppAmount: { size: 10, bold: false, leading: 13 },
  ppFurther: { size: 7, bold: false, leading: 8 },
  rcTitle: { size: 11, bold: true, leading: 11 },
  rcHeading: { size: 6, bold: true, leading: 9 },
  rcValue: { size: 8, bold: false, leading: 9 },
  rcAmount: { size: 8, bold: false, leading: 11 },
  rcAcceptance: { size: 6, bold: true, leading: 8 },
} as const;

export type Lang = "de" | "fr" | "it" | "en";

/** Prescribed headings. These are fixed strings, not free translation. */
const HEADINGS: Record<Lang, Record<string, string>> = {
  de: {
    receipt: "Empfangsschein",
    paymentPart: "Zahlteil",
    account: "Konto / Zahlbar an",
    reference: "Referenz",
    additional: "Zusätzliche Informationen",
    payableBy: "Zahlbar durch",
    payableByBlank: "Zahlbar durch (Name/Adresse)",
    currency: "Währung",
    amount: "Betrag",
    acceptance: "Annahmestelle",
    separate: "Vor der Einzahlung abzutrennen",
  },
  fr: {
    receipt: "Récépissé",
    paymentPart: "Section paiement",
    account: "Compte / Payable à",
    reference: "Référence",
    additional: "Informations supplémentaires",
    payableBy: "Payable par",
    payableByBlank: "Payable par (nom/adresse)",
    currency: "Monnaie",
    amount: "Montant",
    acceptance: "Point de dépôt",
    separate: "A détacher avant le versement",
  },
  it: {
    receipt: "Ricevuta",
    paymentPart: "Sezione pagamento",
    account: "Conto / Pagabile a",
    reference: "Riferimento",
    additional: "Informazioni supplementari",
    payableBy: "Pagabile da",
    payableByBlank: "Pagabile da (nome/indirizzo)",
    currency: "Valuta",
    amount: "Importo",
    acceptance: "Punto di accettazione",
    separate: "Da staccare prima del versamento",
  },
  en: {
    receipt: "Receipt",
    paymentPart: "Payment part",
    account: "Account / Payable to",
    reference: "Reference",
    additional: "Additional information",
    payableBy: "Payable by",
    payableByBlank: "Payable by (name/address)",
    currency: "Currency",
    amount: "Amount",
    acceptance: "Acceptance point",
    separate: "Separate before paying in",
  },
};

export type QrBillData = {
  lang: Lang;
  iban: string;
  creditor: Address;
  debtor?: Address | null;
  currency: string;
  /** Integer Rappen. Null renders the blank amount box with corner marks. */
  amountRappen: number | null;
  referenceType: "QRR" | "SCOR" | "NON";
  reference?: string | null;
  /** Unstructured message; shown under "Additional information". */
  message?: string | null;
  /** The exact 31-line payload string, built by the database. */
  payload: string;
};

export type Address = {
  name: string;
  street?: string | null;
  buildingNo?: string | null;
  postCode?: string | null;
  town?: string | null;
  country?: string | null;
};

export type Fonts = { regular: PDFFont; bold: PDFFont };

/** IBAN is displayed in groups of four, but stored and encoded unformatted. */
export function formatIban(iban: string): string {
  return iban.replace(/(.{4})/g, "$1 ").trim();
}

/**
 * QRR references print in blocks: 2 then 5-5-5-5-5. SCOR prints in fours.
 * The blocks are display only — the payload carries the bare digits.
 */
export function formatReference(ref: string, type: string): string {
  if (type === "QRR") {
    const head = ref.slice(0, 2);
    const rest = ref.slice(2).replace(/(.{5})/g, "$1 ").trim();
    return `${head} ${rest}`;
  }
  return ref.replace(/(.{4})/g, "$1 ").trim();
}

/** Integer Rappen to the printed "1 234.55" form (space-grouped, per SIX). */
export function formatAmount(rappen: number): string {
  const s = (rappen / 100).toFixed(2);
  const [whole, frac] = s.split(".");
  return `${whole.replace(/\B(?=(\d{3})+(?!\d))/g, " ")}.${frac}`;
}

function addressLines(a: Address): string[] {
  const out = [a.name];
  const street = [a.street, a.buildingNo].filter(Boolean).join(" ").trim();
  if (street) out.push(street);
  const town = [a.postCode, a.town].filter(Boolean).join(" ").trim();
  if (town) out.push(town);
  return out.filter((l) => l.length > 0);
}

/**
 * A top-anchored text flow. Returns the y it finished at, so the caller can
 * stack the next block below without hard-coding a position — which is
 * precisely what the Style Guide requires.
 */
function flow(
  page: PDFPage,
  fonts: Fonts,
  originXmm: number,
  startYmm: number,
  widthMm: number,
  blocks: { heading: string; values: string[] }[],
  headingStyle: { size: number; leading: number },
  valueStyle: { size: number; leading: number },
): number {
  let y = startYmm;
  for (const block of blocks) {
    page.drawText(block.heading, {
      x: mm(originXmm),
      y: pageY(y + headingStyle.size * 0.3528),
      size: headingStyle.size,
      font: fonts.bold,
      color: rgb(0, 0, 0),
      maxWidth: mm(widthMm),
    });
    y += headingStyle.leading * 0.3528;

    for (const value of block.values) {
      page.drawText(value, {
        x: mm(originXmm),
        y: pageY(y + valueStyle.size * 0.3528),
        size: valueStyle.size,
        font: fonts.regular,
        color: rgb(0, 0, 0),
        maxWidth: mm(widthMm),
      });
      y += valueStyle.leading * 0.3528;
    }
    // One blank line between blocks, per the Style Guide.
    y += valueStyle.leading * 0.3528;
  }
  return y;
}

/**
 * PDF y grows upward from the bottom of the page; every measurement in the
 * Style Guide is from the top. One conversion, in one place.
 */
let pageHeightMm = GEO.a4.h;
const pageY = (yFromTopMm: number) => mm(pageHeightMm - yFromTopMm);

/** Corner marks for a field left blank, per SIX's asset dimensions. */
function drawCornerMarks(
  page: PDFPage,
  xMm: number,
  yMm: number,
  wMm: number,
  hMm: number,
) {
  const c = GEO.blank.cornerMark;
  const t = GEO.blank.strokePt;
  const corners: [number, number, number, number][] = [
    // [x, y, dx, dy] for each of the four corners: two strokes each.
    [xMm, yMm, 1, 1],
    [xMm + wMm, yMm, -1, 1],
    [xMm, yMm + hMm, 1, -1],
    [xMm + wMm, yMm + hMm, -1, -1],
  ];
  for (const [cx, cy, dx, dy] of corners) {
    page.drawLine({
      start: { x: mm(cx), y: pageY(cy) },
      end: { x: mm(cx + dx * c), y: pageY(cy) },
      thickness: t,
      color: rgb(0, 0, 0),
    });
    page.drawLine({
      start: { x: mm(cx), y: pageY(cy) },
      end: { x: mm(cx), y: pageY(cy + dy * c) },
      thickness: t,
      color: rgb(0, 0, 0),
    });
  }
}

/**
 * The Swiss cross, reproduced from SIX's official CH-Kreuz_7mm.svg rather than
 * hand-drawn. That file is four shapes in a 19.8-unit viewBox — a black square,
 * two white bars, and a white border — so it needs no SVG parser.
 *
 * Note the official artwork is very slightly off-centre (the bars sit ~0.13 mm
 * high). That is reproduced faithfully: this is the mark banks are calibrated
 * against, and "correcting" it would be a deviation from the specification.
 */
function drawSwissCross(page: PDFPage, centreXmm: number, centreYmm: number) {
  const S = 7; // mandated 7 x 7 mm outer footprint
  const u = S / 19.8; // SVG unit -> mm
  const x0 = centreXmm - S / 2;
  const y0 = centreYmm - S / 2;

  const rect = (
    sx: number,
    sy: number,
    sw: number,
    sh: number,
    white: boolean,
  ) =>
    page.drawRectangle({
      x: mm(x0 + sx * u),
      y: pageY(y0 + (sy + sh) * u),
      width: mm(sw * u),
      height: mm(sh * u),
      color: white ? rgb(1, 1, 1) : rgb(0, 0, 0),
    });

  // White outer square (the border), then the black square inset by 0.7 units,
  // then the two white bars. Equivalent to the stroked original and simpler.
  rect(0, 0, 19.8, 19.8, true);
  rect(0.7, 0.7, 18.4, 18.4, false);
  rect(8.3, 4.0, 3.3, 11.0, true);
  rect(4.4, 7.9, 11.0, 3.3, true);
}

/** Draws the QR module matrix as vector rectangles — no raster anywhere. */
function drawQrMatrix(
  page: PDFPage,
  matrix: boolean[][],
  xMm: number,
  yMm: number,
  sizeMm: number,
) {
  const n = matrix.length;
  const module = sizeMm / n;
  for (let row = 0; row < n; row++) {
    for (let col = 0; col < n; col++) {
      if (!matrix[row][col]) continue;
      page.drawRectangle({
        x: mm(xMm + col * module),
        y: pageY(yMm + (row + 1) * module),
        // A hairline overlap prevents seams between adjacent modules when a
        // viewer antialiases; without it the code develops white grid lines.
        width: mm(module) + 0.15,
        height: mm(module) + 0.15,
        color: rgb(0, 0, 0),
      });
    }
  }
}

/**
 * Draws the receipt and payment part across the bottom 105 mm of the page,
 * plus the two separation lines the specification requires for a PDF (paper
 * QR-bills use perforation instead).
 */
export function drawQrBill(
  page: PDFPage,
  fonts: Fonts,
  data: QrBillData,
  qrMatrix: boolean[][],
  pageHeight = GEO.a4.h,
) {
  pageHeightMm = pageHeight;
  const t = HEADINGS[data.lang] ?? HEADINGS.de;
  const bandTop = pageHeight - GEO.band.h;
  const ppX = GEO.payment.x;

  // -- separation lines (PDF delivery: printed lines, not perforation) -------
  page.drawLine({
    start: { x: 0, y: pageY(bandTop) },
    end: { x: mm(GEO.a4.w), y: pageY(bandTop) },
    thickness: 0.5,
    color: rgb(0, 0, 0),
    dashArray: [mm(2), mm(2)],
  });
  page.drawLine({
    start: { x: mm(ppX), y: pageY(bandTop) },
    end: { x: mm(ppX), y: pageY(pageHeight) },
    thickness: 0.5,
    color: rgb(0, 0, 0),
    dashArray: [mm(2), mm(2)],
  });
  page.drawText(t.separate, {
    x: mm(GEO.margin),
    y: pageY(bandTop - 1.5),
    size: 7,
    font: fonts.regular,
    color: rgb(0, 0, 0),
  });

  // ------------------------------------------------------------- receipt ---
  const rc = GEO.rc;
  page.drawText(t.receipt, {
    x: mm(rc.title.x),
    y: pageY(bandTop + rc.title.y + 4),
    size: TYPE.rcTitle.size,
    font: fonts.bold,
    color: rgb(0, 0, 0),
  });

  const rcBlocks = [
    {
      heading: t.account,
      values: [formatIban(data.iban), ...addressLines(data.creditor)],
    },
  ];
  if (data.referenceType !== "NON" && data.reference) {
    rcBlocks.push({
      heading: t.reference,
      values: [formatReference(data.reference, data.referenceType)],
    });
  }
  rcBlocks.push({
    heading: data.debtor ? t.payableBy : t.payableByBlank,
    values: data.debtor ? addressLines(data.debtor) : [],
  });

  const rcEnd = flow(
    page, fonts, rc.info.x, bandTop + rc.info.y, rc.info.w, rcBlocks,
    TYPE.rcHeading, TYPE.rcValue,
  );
  if (!data.debtor) {
    drawCornerMarks(
      page, rc.info.x, rcEnd,
      GEO.blank.payableByRC.w, GEO.blank.payableByRC.h,
    );
  }

  // Amount row: currency and amount side by side.
  page.drawText(t.currency, {
    x: mm(rc.amount.x), y: pageY(bandTop + rc.amount.y + 2.5),
    size: TYPE.rcHeading.size, font: fonts.bold, color: rgb(0, 0, 0),
  });
  page.drawText(t.amount, {
    x: mm(rc.amount.x + 12), y: pageY(bandTop + rc.amount.y + 2.5),
    size: TYPE.rcHeading.size, font: fonts.bold, color: rgb(0, 0, 0),
  });
  page.drawText(data.currency, {
    x: mm(rc.amount.x), y: pageY(bandTop + rc.amount.y + 7),
    size: TYPE.rcValue.size, font: fonts.regular, color: rgb(0, 0, 0),
  });
  if (data.amountRappen !== null) {
    page.drawText(formatAmount(data.amountRappen), {
      x: mm(rc.amount.x + 12), y: pageY(bandTop + rc.amount.y + 7),
      size: TYPE.rcValue.size, font: fonts.regular, color: rgb(0, 0, 0),
    });
  } else {
    drawCornerMarks(
      page, rc.amount.x + 12, bandTop + rc.amount.y + 3,
      GEO.blank.amountRC.w, GEO.blank.amountRC.h,
    );
  }

  page.drawText(t.acceptance, {
    // Right-aligned to the receipt's content edge, per the Style Guide.
    x: mm(rc.acceptance.x + rc.acceptance.w) -
       fonts.bold.widthOfTextAtSize(t.acceptance, TYPE.rcAcceptance.size),
    y: pageY(bandTop + rc.acceptance.y + 3.3),
    size: TYPE.rcAcceptance.size, font: fonts.bold, color: rgb(0, 0, 0),
  });

  // -------------------------------------------------------- payment part ---
  const pp = GEO.pp;
  page.drawText(t.paymentPart, {
    x: mm(ppX + pp.title.x),
    y: pageY(bandTop + pp.title.y + 4),
    size: TYPE.ppTitle.size, font: fonts.bold, color: rgb(0, 0, 0),
  });

  drawQrMatrix(page, qrMatrix, ppX + pp.qr.x, bandTop + pp.qr.y, pp.qr.size);
  drawSwissCross(
    page,
    ppX + pp.qr.x + pp.qr.size / 2,
    bandTop + pp.qr.y + pp.qr.size / 2,
  );

  page.drawText(t.currency, {
    x: mm(ppX + pp.amount.x), y: pageY(bandTop + pp.amount.y + 3),
    size: TYPE.ppHeading.size, font: fonts.bold, color: rgb(0, 0, 0),
  });
  page.drawText(t.amount, {
    x: mm(ppX + pp.amount.x + 16), y: pageY(bandTop + pp.amount.y + 3),
    size: TYPE.ppHeading.size, font: fonts.bold, color: rgb(0, 0, 0),
  });
  page.drawText(data.currency, {
    x: mm(ppX + pp.amount.x), y: pageY(bandTop + pp.amount.y + 8),
    size: TYPE.ppAmount.size, font: fonts.regular, color: rgb(0, 0, 0),
  });
  if (data.amountRappen !== null) {
    page.drawText(formatAmount(data.amountRappen), {
      x: mm(ppX + pp.amount.x + 16), y: pageY(bandTop + pp.amount.y + 8),
      size: TYPE.ppAmount.size, font: fonts.regular, color: rgb(0, 0, 0),
    });
  } else {
    drawCornerMarks(
      page, ppX + pp.amount.x + 16, bandTop + pp.amount.y + 4,
      GEO.blank.amountPP.w, GEO.blank.amountPP.h,
    );
  }

  const ppBlocks = [
    {
      heading: t.account,
      values: [formatIban(data.iban), ...addressLines(data.creditor)],
    },
  ];
  if (data.referenceType !== "NON" && data.reference) {
    ppBlocks.push({
      heading: t.reference,
      values: [formatReference(data.reference, data.referenceType)],
    });
  }
  if (data.message) {
    ppBlocks.push({ heading: t.additional, values: [data.message] });
  }
  ppBlocks.push({
    heading: data.debtor ? t.payableBy : t.payableByBlank,
    values: data.debtor ? addressLines(data.debtor) : [],
  });

  const ppEnd = flow(
    page, fonts, ppX + pp.info.x, bandTop + pp.info.y, pp.info.w, ppBlocks,
    TYPE.ppHeading, TYPE.ppValue,
  );
  if (!data.debtor) {
    drawCornerMarks(
      page, ppX + pp.info.x, ppEnd,
      GEO.blank.payableByPP.w, GEO.blank.payableByPP.h,
    );
  }
}
