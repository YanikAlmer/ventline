// Resolves a customer magic link.
//
// This function exists so that the service-role key never enters web/ or ios/.
// It is deliberately thin, and the division of labour is the point:
//
//   **Postgres decides, this function signs.**
//
// resolve_document_link validates the token, records the view, and returns the
// exact storage path that token entitles the holder to. This function mints a
// short-lived signed URL for *that path and nothing else*. It performs no
// authorisation of its own, so there is no second place for the rules to live
// and no way for the two to disagree.
//
// The RPC is granted to service_role only. `anon` must never reach it: a token
// is a bearer credential, and a publicly callable resolver turns a leaked URL
// into a queryable oracle.

import { createClient } from "jsr:@supabase/supabase-js@2";

/** Long enough to open the PDF, short enough that a shared URL goes stale. */
const SIGNED_URL_TTL_SECONDS = 15 * 60;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * Coarse only. The full user-agent is a fingerprinting surface and revDSG
 * Art. 6 makes "we might want it later" not a purpose; the browser family is
 * enough to answer "did they actually open it, and on what".
 */
function userAgentFamily(ua: string | null): string | null {
  if (!ua) return null;
  if (/\bEdg\//.test(ua)) return "Edge";
  if (/\bOPR\//.test(ua)) return "Opera";
  if (/\bChrome\//.test(ua)) return "Chrome";
  if (/\bSafari\//.test(ua)) return "Safari";
  if (/\bFirefox\//.test(ua)) return "Firefox";
  return "Other";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  let token: string | undefined;
  try {
    ({ token } = await req.json());
  } catch {
    return Response.json({ ok: false, reason: "bad_request" }, {
      status: 400,
      headers: CORS,
    });
  }
  if (!token || typeof token !== "string") {
    return Response.json({ ok: false, reason: "bad_request" }, {
      status: 400,
      headers: CORS,
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data, error } = await supabase.rpc("resolve_document_link", {
    p_token: token,
    p_user_agent_family: userAgentFamily(req.headers.get("user-agent")),
  });

  // One indistinguishable answer for unknown, revoked, expired and broken —
  // the database already collapses the first three, and an internal error must
  // not become an oracle either.
  if (error || !data || data.ok !== true) {
    return Response.json({ ok: false, reason: "invalid_or_expired" }, {
      status: 404,
      headers: CORS,
    });
  }

  const pdf = data.pdf as { bucket?: string; path?: string } | null;
  let url: string | null = null;
  if (pdf?.bucket && pdf?.path) {
    const { data: signed } = await supabase.storage
      .from(pdf.bucket)
      .createSignedUrl(pdf.path, SIGNED_URL_TTL_SECONDS);
    url = signed?.signedUrl ?? null;
  }

  // The path itself is not returned — only the signed URL. A path is a hint
  // about storage layout that the holder of a link has no use for.
  const { pdf: _dropped, ...rest } = data as Record<string, unknown>;

  return Response.json({ ...rest, pdf_url: url }, {
    headers: { ...CORS, "cache-control": "no-store" },
  });
});
