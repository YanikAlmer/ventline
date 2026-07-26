/**
 * Mentions and task references: turning what someone picked into what the
 * database stores, and back into something readable.
 *
 * The body stays plain text. "@Wanda Weber" is literally in `messages.body`,
 * and `message_mentions` records the range it occupies. That matters because
 * the body is read in places that know nothing about annotations — the push
 * notification preview, the inbox thread preview, the customer portal, a
 * search snippet — and all of them should show a name rather than a token like
 * `<@uuid>` or an empty gap.
 *
 * Offsets are **UTF-16 code units**, which is what JavaScript strings index in
 * natively and what Swift reaches through `String.utf16`. The contract is
 * recorded on the columns themselves; nothing server-side ever slices with it.
 */

export type PendingAnnotation = {
  kind: "mention" | "task";
  /** profile_id for a mention, task_id for a reference. */
  id: string;
  /** Exactly the run inserted into the body, including the @ or #. */
  text: string;
};

export type ResolvedAnnotation = PendingAnnotation & {
  start: number;
  length: number;
};

/**
 * Offsets are computed **once, from the final text**, rather than maintained
 * through every keystroke. Someone types around a mention, deletes half of it,
 * pastes over it; tracking a live range through all of that is a source of
 * off-by-ones, and none of it is observable until a message renders wrong.
 *
 * So: find each inserted run in the body it was actually sent with. A run the
 * user edited away is simply dropped — which is the right outcome, because a
 * name that is no longer in the text should not notify anybody.
 */
export function resolveAnnotations(
  body: string,
  pending: readonly PendingAnnotation[],
): ResolvedAnnotation[] {
  const claimed: Array<[number, number]> = [];
  const resolved: ResolvedAnnotation[] = [];

  for (const item of pending) {
    if (!item.text) continue;
    // The same person can be mentioned twice in one message, so each pending
    // entry has to claim a *different* occurrence of the same text.
    let from = 0;
    let index = -1;
    for (;;) {
      index = body.indexOf(item.text, from);
      if (index === -1) break;
      const end = index + item.text.length;
      const overlaps = claimed.some(([s, e]) => index < e && end > s);
      if (!overlaps) break;
      from = index + 1;
    }
    if (index === -1) continue;

    claimed.push([index, index + item.text.length]);
    resolved.push({ ...item, start: index, length: item.text.length });
  }

  return resolved.sort((a, b) => a.start - b.start);
}

/** The `p_mentions` shape send_message expects. */
export function mentionsPayload(resolved: readonly ResolvedAnnotation[]) {
  return resolved
    .filter((a) => a.kind === "mention")
    .map((a) => ({
      profile_id: a.id,
      start_offset: a.start,
      length: a.length,
    }));
}

/** The `p_refs` shape send_message expects. */
export function refsPayload(resolved: readonly ResolvedAnnotation[]) {
  return resolved
    .filter((a) => a.kind === "task")
    .map((a) => ({
      kind: "task",
      task_id: a.id,
      start_offset: a.start,
      length: a.length,
    }));
}

export type BodySegment =
  | { type: "text"; text: string }
  | { type: "mention"; text: string; profileId: string }
  | { type: "task"; text: string; taskId: string };

type StoredAnnotation = {
  kind: "mention" | "task";
  id: string;
  start_offset: number | null;
  length: number | null;
};

/**
 * Split a body into plain and annotated runs for rendering.
 *
 * Every stored range is treated as a **hint that must still be true**. A row
 * whose offsets fall outside the body, or overlap a range already taken, is
 * skipped and its text renders plain. Offsets are written by a client and read
 * by a different one, possibly years later and possibly by a version that
 * counted differently — a wrong highlight is acceptable, a crash or a garbled
 * message is not.
 */
export function segmentBody(
  body: string,
  annotations: readonly StoredAnnotation[],
): BodySegment[] {
  const usable = annotations
    .filter(
      (a) =>
        a.start_offset != null &&
        a.length != null &&
        a.length > 0 &&
        a.start_offset >= 0 &&
        a.start_offset + a.length <= body.length,
    )
    .sort((a, b) => a.start_offset! - b.start_offset!);

  const segments: BodySegment[] = [];
  let cursor = 0;

  for (const annotation of usable) {
    const start = annotation.start_offset!;
    const end = start + annotation.length!;
    if (start < cursor) continue; // overlaps something already emitted

    if (start > cursor) {
      segments.push({ type: "text", text: body.slice(cursor, start) });
    }
    const text = body.slice(start, end);
    segments.push(
      annotation.kind === "mention"
        ? { type: "mention", text, profileId: annotation.id }
        : { type: "task", text, taskId: annotation.id },
    );
    cursor = end;
  }

  if (cursor < body.length) {
    segments.push({ type: "text", text: body.slice(cursor) });
  }
  return segments;
}

/**
 * The token being typed at the caret, if any.
 *
 * Anchored to a word boundary so an email address does not open the picker
 * halfway through, and capped at 40 characters so a long paragraph containing
 * a stray `@` stops querying after the first word.
 */
export type TriggerMatch = {
  sigil: "@" | "#";
  query: string;
  /** Index of the sigil, so the whole run can be replaced on selection. */
  start: number;
};

const TRIGGER = /(?:^|[\s(\[])([@#])([^\s@#]{0,40})$/u;

export function findTrigger(
  text: string,
  caret: number,
): TriggerMatch | null {
  const match = TRIGGER.exec(text.slice(0, caret));
  if (!match) return null;
  return {
    sigil: match[1] as "@" | "#",
    query: match[2],
    start: caret - match[2].length - 1,
  };
}
