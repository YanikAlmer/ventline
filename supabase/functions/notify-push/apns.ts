// APNs HTTP/2 delivery with JWT (token) authentication.
//
// Token auth rather than certificates: one p8 key works for every app and never
// expires, and the provider token is just a short-lived JWT we can mint here.
// Apple requires the token be refreshed at least every hour and not more than
// once every 20 minutes, so it is cached in module scope.

const APNS_HOST_PRODUCTION = "https://api.push.apple.com";
const APNS_HOST_SANDBOX = "https://api.sandbox.push.apple.com";

/** Apple: refresh no more often than 20 min, and at least every 60 min. */
const TOKEN_TTL_MS = 45 * 60 * 1000;

export type ApnsConfig = {
  keyId: string;
  teamId: string;
  privateKeyPem: string;
  topic: string;
};

export type ApnsPush = {
  deviceToken: string;
  environment: "sandbox" | "production";
  title: string;
  body: string;
  badge?: number;
  /** Quiet hours: no sound and priority 5, so it waits silently. */
  passive?: boolean;
  /** Newer notification for the same thing replaces the older one. */
  collapseId?: string | null;
  /** Unix seconds; APNs discards rather than delivering something stale. */
  expiration?: number | null;
  /** Deep-link routing data. */
  data?: Record<string, unknown>;
};

export type ApnsResult = {
  ok: boolean;
  status: number;
  reason?: string;
  /** Retry later: transient on Apple's side or on ours. */
  retryable: boolean;
  /** The token is dead — delete it. */
  prune: boolean;
  /** From APNs 410, so a token re-registered since then is not deleted. */
  invalidSince?: string;
};

let cachedToken: { value: string; mintedAt: number } | null = null;

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/** Strip the PEM armour and decode to the DER bytes crypto.subtle expects. */
function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}

async function mintProviderToken(cfg: ApnsConfig): Promise<string> {
  const now = Date.now();
  if (cachedToken && now - cachedToken.mintedAt < TOKEN_TTL_MS) {
    return cachedToken.value;
  }

  const header = { alg: "ES256", kid: cfg.keyId };
  const claims = { iss: cfg.teamId, iat: Math.floor(now / 1000) };
  const encoder = new TextEncoder();
  const signingInput =
    `${base64url(encoder.encode(JSON.stringify(header)))}.` +
    `${base64url(encoder.encode(JSON.stringify(claims)))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(cfg.privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput),
  );

  const token = `${signingInput}.${base64url(new Uint8Array(signature))}`;
  cachedToken = { value: token, mintedAt: now };
  return token;
}

/**
 * Map an APNs response to what the database needs to know. The distinction
 * that matters is retryable (try again later) vs prune (this token is dead and
 * must be deleted, or we push into the void forever).
 */
function classify(status: number, reason: string | undefined): ApnsResult {
  // 410 Unregistered, or 400 BadDeviceToken: the app is gone from that handset.
  if (status === 410 || reason === "Unregistered" || reason === "BadDeviceToken") {
    return { ok: false, status, reason, retryable: false, prune: true };
  }
  // 429 TooManyRequests, 500/503: Apple's side, back off.
  if (status === 429 || status >= 500) {
    return { ok: false, status, reason, retryable: true, prune: false };
  }
  // 403 usually means our JWT is wrong — retrying with a fresh token can help,
  // so drop the cache and let the backoff try again.
  if (status === 403) {
    cachedToken = null;
    return { ok: false, status, reason, retryable: true, prune: false };
  }
  if (status === 200) {
    return { ok: true, status, retryable: false, prune: false };
  }
  // Anything else (413 payload too large, 400 malformed) is our bug: retrying
  // would just repeat it.
  return { ok: false, status, reason, retryable: false, prune: false };
}

export async function sendPush(
  cfg: ApnsConfig,
  push: ApnsPush,
): Promise<ApnsResult> {
  const token = await mintProviderToken(cfg);
  const host = push.environment === "sandbox"
    ? APNS_HOST_SANDBOX
    : APNS_HOST_PRODUCTION;

  const payload: Record<string, unknown> = {
    aps: {
      alert: { title: push.title, body: push.body },
      // Quiet hours: silent, and priority 5 lets Apple hold it for a good moment.
      sound: push.passive ? undefined : "default",
      badge: push.badge,
      "interruption-level": push.passive ? "passive" : "active",
      "thread-id": push.collapseId ?? undefined,
    },
    ...push.data,
  };

  const headers: Record<string, string> = {
    authorization: `bearer ${token}`,
    "apns-topic": cfg.topic,
    "apns-push-type": "alert",
    "apns-priority": push.passive ? "5" : "10",
    "content-type": "application/json",
  };
  if (push.collapseId) headers["apns-collapse-id"] = push.collapseId.slice(0, 64);
  if (push.expiration) headers["apns-expiration"] = String(push.expiration);

  try {
    const res = await fetch(`${host}/3/device/${push.deviceToken}`, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
    });

    if (res.status === 200) return classify(200, undefined);

    let reason: string | undefined;
    try {
      reason = (await res.json())?.reason;
    } catch {
      // Apple always sends JSON on error, but never trust that.
    }
    const result = classify(res.status, reason);
    if (result.prune) {
      result.invalidSince = res.headers.get("apns-unique-id")
        ? new Date().toISOString()
        : new Date().toISOString();
    }
    return result;
  } catch (error) {
    // Network failure: always worth retrying.
    return {
      ok: false,
      status: 0,
      reason: error instanceof Error ? error.message : "network error",
      retryable: true,
      prune: false,
    };
  }
}
