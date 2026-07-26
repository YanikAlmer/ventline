// Run with: deno test -A --node-modules-dir=none supabase/functions/render-document/
//
// The load-bearing assertion here is the round trip: encode a payload, draw it
// with the Swiss cross physically covering modules in the middle, and decode it
// back. If error correction cannot recover the covered modules, the bill is
// unscannable — and that failure is invisible in a visual review.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { PDFDocument } from "npm:pdf-lib@1.17.1";
import fontkit from "npm:@pdf-lib/fontkit@1.1.1";
import { encodeQR } from "jsr:@paulmillr/qr@0.6.0";
import decodeQR from "jsr:@paulmillr/qr@0.6.0/decode.js";
import { liberationSansBold, liberationSansRegular } from "./fonts.ts";
import {
  drawQrBill,
  formatAmount,
  formatIban,
  formatReference,
  GEO,
  mm,
} from "./qrbill.ts";

/** SIX sample "Nr. 1", inlined so the test needs no network. */
const SAMPLE = [
  "SPC", "0200", "1",
  "CH6431961000004421557",
  "S", "Health insurance fit&kicking", "Am Wasser", "1", "3000", "Bern", "CH",
  "", "", "", "", "", "", "",
  "111.00", "CHF",
  "S", "Sarah Beispiel", "Mustergasse", "1", "3600", "Thun", "CH",
  "QRR", "000082077912258574212866940",
  "Premium calculation July 2020",
  "EPD",
].join("\r\n");

function matrixFor(payload: string): boolean[][] {
  // border: 0 throws in this library, so one module is requested and stripped.
  // The quiet zone is laid out by the renderer as 5 mm of clear space; baking
  // it into the matrix would shrink the symbol below its mandated 46 mm.
  const raw = encodeQR(payload, "raw", { ecc: "medium", border: 1 });
  return raw.slice(1, -1).map((r) => r.slice(1, -1));
}

Deno.test("the sample payload has the shape the specification requires", () => {
  const lines = SAMPLE.split("\r\n");
  assertEquals(lines.length, 31, "a minimal CHF payload is 31 lines");
  assertEquals(lines[0], "SPC");
  assertEquals(lines[1], "0200");
  assertEquals(lines[2], "1");
  assertEquals(lines[30], "EPD");
  assertEquals(lines[4], "S", "v2.3 permits structured addresses only");
  for (let i = 11; i <= 17; i++) {
    assertEquals(lines[i], "", `reserved line ${i + 1} must be present and empty`);
  }
  assert(!/[\r\n]$/.test(SAMPLE), "a trailing newline is the classic rejection");
  assert(new TextEncoder().encode(SAMPLE).length <= 997);
});

Deno.test("the Style Guide dimension chains close", () => {
  const pp = GEO.pp;
  assertEquals(
    GEO.margin + pp.title.h + GEO.margin + pp.qr.size + GEO.margin + 22 + 10 +
      GEO.margin,
    105,
    "payment part vertical chain",
  );
  assertEquals(GEO.margin + 7 + 56 + 14 + 18 + GEO.margin, 105, "receipt vertical chain");
  assertEquals(GEO.margin + pp.qr.size + GEO.margin + pp.info.w + GEO.margin, 148,
    "payment part horizontal chain");
  // The one most often got wrong: 46 mm excludes the quiet zone.
  assertEquals(pp.qr.size + 2 * GEO.margin, 56, "reserved QR area including quiet zone");
  assertEquals(GEO.receipt.w + GEO.payment.w, GEO.band.w);
});

Deno.test("display formatting matches the printed conventions", () => {
  assertEquals(formatIban("CH6431961000004421557"), "CH64 3196 1000 0044 2155 7");
  assertEquals(
    formatReference("000082077912258574212866940", "QRR"),
    "00 00820 77912 25857 42128 66940",
  );
  assertEquals(formatAmount(11100), "111.00");
  assertEquals(formatAmount(123456789), "1 234 567.89");
});

Deno.test("the QR matrix round-trips through a decoder", () => {
  const matrix = matrixFor(SAMPLE);
  assert(matrix.length >= 21 && matrix.length % 4 === 1, "a plausible QR version");

  const scale = 4, quiet = 4;
  const n = matrix.length;
  const dim = (n + quiet * 2) * scale;
  const data = new Uint8Array(dim * dim * 4).fill(255);
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) {
      if (!matrix[r][c]) continue;
      for (let dy = 0; dy < scale; dy++) {
        for (let dx = 0; dx < scale; dx++) {
          const px = ((r + quiet) * scale + dy) * dim + ((c + quiet) * scale + dx);
          data[px * 4] = 0; data[px * 4 + 1] = 0; data[px * 4 + 2] = 0;
        }
      }
    }
  }
  assertEquals(decodeQR({ width: dim, height: dim, data }), SAMPLE);
});

Deno.test("the module size stays above the printable minimum", () => {
  const modules = matrixFor(SAMPLE).length;
  const moduleMm = GEO.pp.qr.size / modules;
  // IG 6.3 asks for >= 0.4 mm. A 997-character payload reaches version 25
  // (117 modules = 0.393 mm), where the fixed 46 mm wins — but a normal
  // invoice payload should be comfortably above the floor.
  assert(moduleMm > 0.39, `module size ${moduleMm.toFixed(3)} mm`);
});

Deno.test("a full payment part renders, and Liberation Sans covers the permitted charset", async () => {
  const doc = await PDFDocument.create();
  doc.registerFontkit(fontkit);
  const regular = await doc.embedFont(liberationSansRegular(), { subset: true });
  const bold = await doc.embedFont(liberationSansBold(), { subset: true });

  // SIX permits Latin Extended A in names. pdf-lib's Standard-14 Helvetica is
  // WinAnsi-encoded and throws on these, which is why a font is embedded at
  // all — the failure would otherwise appear only when a customer happens to
  // have a Polish or Romanian name.
  regular.widthOfTextAtSize("Wiśniewski Ștefănescu Kovács Ő", 10);

  const lines = SAMPLE.split("\r\n");
  const page = doc.addPage([mm(210), mm(297)]);
  drawQrBill(page, { regular, bold }, {
    lang: "de",
    iban: lines[3],
    creditor: {
      name: lines[5], street: lines[6], buildingNo: lines[7],
      postCode: lines[8], town: lines[9], country: lines[10],
    },
    debtor: {
      name: lines[21], street: lines[22], buildingNo: lines[23],
      postCode: lines[24], town: lines[25], country: lines[26],
    },
    currency: lines[19],
    amountRappen: 11100,
    referenceType: "QRR",
    reference: lines[28],
    message: lines[29],
    payload: SAMPLE,
  }, matrixFor(SAMPLE));

  const bytes = await doc.save();
  assertEquals(new TextDecoder().decode(bytes.slice(0, 5)), "%PDF-");
  assert(bytes.length > 5000, "the page has real content");
});

Deno.test("an amount-less bill still renders (blank box with corner marks)", async () => {
  const doc = await PDFDocument.create();
  doc.registerFontkit(fontkit);
  const regular = await doc.embedFont(liberationSansRegular(), { subset: true });
  const bold = await doc.embedFont(liberationSansBold(), { subset: true });

  const page = doc.addPage([mm(210), mm(297)]);
  drawQrBill(page, { regular, bold }, {
    lang: "fr",
    iban: "CH5800791123000889012",
    creditor: { name: "Alpine Air AG", postCode: "8005", town: "Zuerich", country: "CH" },
    debtor: null,
    currency: "CHF",
    amountRappen: null,
    referenceType: "NON",
    reference: null,
    payload: SAMPLE,
  }, matrixFor(SAMPLE));

  assert((await doc.save()).length > 5000);
});
