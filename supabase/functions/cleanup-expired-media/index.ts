// cleanup-expired-media — Milestone 2 stub.
//
// Planned flow: runs on a schedule (Supabase cron). Two jobs:
//   1. Call public.purge_expired_messages() to hard-delete messages whose
//      expires_at has passed (RLS already hides them from clients; this is
//      the permanent cleanup). The delete trigger enqueues attachment paths
//      into public.media_deletion_queue.
//   2. Drain media_deletion_queue: remove each storage object via the
//      Storage API (service role), then delete the queue row.
//
// Not deployed in Milestone 1.

Deno.serve(() =>
  new Response(
    JSON.stringify({ error: "cleanup-expired-media is not implemented yet (milestone 2)" }),
    { status: 501, headers: { "Content-Type": "application/json" } },
  )
);
