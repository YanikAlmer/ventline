// notify-push — Milestone 2 stub.
//
// Planned flow: a Database Webhook fires on INSERT into public.messages and
// calls this function. It resolves recipients (task assignees + project
// foremen + office roles, minus the sender), looks up their APNs tokens in
// public.devices, and sends pushes via APNs HTTP/2 token auth (p8 key stored
// in function secrets: APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY, APNS_TOPIC).
//
// Not deployed in Milestone 1.

Deno.serve(() =>
  new Response(
    JSON.stringify({ error: "notify-push is not implemented yet (milestone 2)" }),
    { status: 501, headers: { "Content-Type": "application/json" } },
  )
);
