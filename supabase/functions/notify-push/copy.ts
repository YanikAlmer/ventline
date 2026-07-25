// Notification copy, per device locale.
//
// The device's own locale is used, not the sender's: a German-speaking foreman
// and an English-speaking manager can be in the same audience for one event.
// Swiss Standard German never uses "ß".

export type NotificationRow = {
  kind:
    | "chat_message"
    | "mention"
    | "task_assigned"
    | "task_status"
    | "task_due_soon"
    | "task_overdue";
  project_name: string;
  task_title: string | null;
  task_due_date: string | null;
  actor_name: string | null;
  message_kind: string | null;
  message_preview: string | null;
  payload: Record<string, unknown>;
};

type Copy = { title: string; body: string };

const STATUS_DE: Record<string, string> = {
  todo: "Offen",
  in_progress: "In Arbeit",
  blocked: "Blockiert",
  done: "Erledigt",
  approved: "Freigegeben",
};

const STATUS_EN: Record<string, string> = {
  todo: "To do",
  in_progress: "In progress",
  blocked: "Blocked",
  done: "Done",
  approved: "Approved",
};

/** Media has no preview by design — a caption must not reach a lock screen. */
function mediaBody(messageKind: string | null, de: boolean): string {
  switch (messageKind) {
    case "photo":
      return de ? "hat ein Foto geschickt" : "sent a photo";
    case "voice":
      return de ? "hat eine Sprachnachricht geschickt" : "sent a voice message";
    case "video":
      return de ? "hat ein Video geschickt" : "sent a video";
    default:
      return de ? "hat etwas geschickt" : "sent something";
  }
}

export function buildCopy(row: NotificationRow, locale: string): Copy {
  const de = !locale.toLowerCase().startsWith("en");
  const who = row.actor_name ?? (de ? "Jemand" : "Someone");
  // Task threads are titled by the task; project threads by the project.
  const where = row.task_title ?? row.project_name;

  switch (row.kind) {
    case "chat_message": {
      const body = row.message_preview ?? mediaBody(row.message_kind, de);
      return { title: where, body: `${who}: ${body}` };
    }

    case "mention": {
      const body = row.message_preview ?? mediaBody(row.message_kind, de);
      return {
        title: de ? `${who} hat dich erwähnt` : `${who} mentioned you`,
        body: `${where} · ${body}`,
      };
    }

    case "task_assigned":
      return {
        title: de ? "Neues Arbeitspaket" : "New work package",
        body: de
          ? `${who} hat dir "${where}" zugewiesen`
          : `${who} assigned you "${where}"`,
      };

    case "task_status": {
      const status = String(row.payload?.status ?? "");
      const label = (de ? STATUS_DE : STATUS_EN)[status] ?? status;
      return {
        title: where,
        body: de
          ? `${who} hat den Status auf "${label}" gesetzt`
          : `${who} set the status to "${label}"`,
      };
    }

    case "task_due_soon":
      return {
        title: de ? "Morgen fällig" : "Due tomorrow",
        body: `${where} · ${row.project_name}`,
      };

    case "task_overdue":
      return {
        title: de ? "Überfällig" : "Overdue",
        body: `${where} · ${row.project_name}`,
      };
  }
}
