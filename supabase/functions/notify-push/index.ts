// notify-push — drains the notification outbox and delivers via APNs.
//
// Woken by a payload-free nudge from app.nudge_notifier() (pg_net) on every
// write that produces a notification, and by a pg_cron drain every minute as a
// safety net. It is therefore invoked far more often than it has work; an empty
// claim is the normal case and must be cheap.
//
// The function never decides WHO gets a notification. That is
// app.notification_recipients, which re-applies the same visibility predicate
// the RLS policies use — the drain runs with auth.uid() = NULL, so it cannot
// rely on RLS itself. This function only formats and delivers what the database
// hands it, then reports back what APNs said.
//
// Secrets (supabase secrets set):
//   APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY (p8 contents), APNS_TOPIC
//   NOTIFY_PUSH_SECRET  — shared with the vault secret the nudge sends

import { createClient } from "jsr:@supabase/supabase-js@2";

import { sendPush, type ApnsConfig, type ApnsResult } from "./apns.ts";
import { buildCopy, type NotificationRow } from "./copy.ts";

type ClaimRow = NotificationRow & {
  id: string;
  project_id: string;
  task_id: string | null;
  message_id: string | null;
  profile_id: string;
  passive: boolean;
  badge: number;
  device_id: string;
  push_token: string;
  platform: "ios" | "web";
  apns_environment: "sandbox" | "production";
  locale: string;
  expiration_epoch: number | null;
  collapse_id: string | null;
};

type SettleRow = {
  id: string;
  device_id: string;
  ok: boolean;
  retryable: boolean;
  prune?: boolean;
  invalid_since?: string;
  error?: string;
};

const BATCH_LIMIT = 100;

function apnsConfig(): ApnsConfig | null {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const privateKeyPem = Deno.env.get("APNS_PRIVATE_KEY");
  const topic = Deno.env.get("APNS_TOPIC");
  if (!keyId || !teamId || !privateKeyPem || !topic) return null;
  return { keyId, teamId, privateKeyPem, topic };
}

Deno.serve(async (req) => {
  // The nudge comes from Postgres, not from a user. A shared secret keeps the
  // endpoint from being a free "drain the queue" button for the internet.
  const expected = Deno.env.get("NOTIFY_PUSH_SECRET");
  if (expected && req.headers.get("x-ventline-notify-secret") !== expected) {
    return new Response(JSON.stringify({ error: "forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const cfg = apnsConfig();
  if (!cfg) {
    // Deliberately not an error: until the Apple credentials exist the outbox
    // simply accumulates, and nothing else in the app is affected.
    return new Response(
      JSON.stringify({ skipped: "APNs credentials not configured" }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data, error } = await supabase.rpc("claim_notification_batch", {
    p_limit: BATCH_LIMIT,
  });
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const rows = (data ?? []) as ClaimRow[];
  if (rows.length === 0) {
    return new Response(JSON.stringify({ delivered: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // One outbox row fans out to every device of every recipient, so deliver
  // concurrently rather than serially — a 30-person crew is 30+ round trips.
  const settled: SettleRow[] = await Promise.all(
    rows.map(async (row): Promise<SettleRow> => {
      // Web push is not implemented yet; treat as delivered so the row does not
      // retry forever once a web device registers.
      if (row.platform !== "ios") {
        return { id: row.id, device_id: row.device_id, ok: true, retryable: false };
      }

      const copy = buildCopy(row, row.locale);
      const result: ApnsResult = await sendPush(cfg, {
        deviceToken: row.push_token,
        environment: row.apns_environment,
        title: copy.title,
        body: copy.body,
        badge: row.badge,
        passive: row.passive,
        collapseId: row.collapse_id,
        expiration: row.expiration_epoch,
        // Deep link: enough for the app to open the right thread.
        data: {
          project_id: row.project_id,
          task_id: row.task_id,
          message_id: row.message_id,
          kind: row.kind,
        },
      });

      return {
        id: row.id,
        device_id: row.device_id,
        ok: result.ok,
        retryable: result.retryable,
        prune: result.prune,
        invalid_since: result.invalidSince,
        error: result.ok ? undefined : `${result.status} ${result.reason ?? ""}`.trim(),
      };
    }),
  );

  const { error: settleError } = await supabase.rpc("settle_notification_batch", {
    p_results: settled,
  });
  if (settleError) {
    // The rows stay in 'sending' and the per-minute drain unsticks them after
    // five minutes, so this is recoverable — but it must be visible.
    console.error("settle failed", settleError.message);
  }

  return new Response(
    JSON.stringify({
      delivered: settled.filter((s) => s.ok).length,
      failed: settled.filter((s) => !s.ok).length,
      pruned: settled.filter((s) => s.prune).length,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
