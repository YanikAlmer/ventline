"use client";

import Link from "next/link";

import { segmentBody } from "@/lib/annotations";

import type { ChatMention, ChatRef } from "./types";

/**
 * A message body with its mentions and task references picked out.
 *
 * Being mentioned yourself reads differently from someone else being
 * mentioned, and the difference has to survive the dark bubble your own
 * messages use — hence the two palettes rather than one colour with opacity.
 */
export function MessageBody({
  body,
  mentions,
  refs,
  projectId,
  currentProfileId,
  own,
  dim,
}: {
  body: string;
  mentions: readonly ChatMention[];
  refs: readonly ChatRef[];
  projectId: string;
  currentProfileId: string;
  own: boolean;
  dim?: boolean;
}) {
  const segments = segmentBody(body, [
    ...mentions.map((m) => ({
      kind: "mention" as const,
      id: m.mentioned_profile_id,
      start_offset: m.start_offset,
      length: m.length,
    })),
    ...refs
      .filter((r) => r.kind === "task" && r.task_id)
      .map((r) => ({
        kind: "task" as const,
        id: r.task_id!,
        start_offset: r.start_offset,
        length: r.length,
      })),
  ]);

  return (
    <p
      className={`whitespace-pre-wrap break-words text-sm ${dim ? "opacity-90" : ""}`}
    >
      {segments.map((segment, index) => {
        if (segment.type === "text") {
          return <span key={index}>{segment.text}</span>;
        }

        if (segment.type === "mention") {
          const isMe = segment.profileId === currentProfileId;
          return (
            <span
              key={index}
              className={`rounded px-1 font-semibold ${
                isMe
                  ? own
                    ? "bg-amber-300 text-slate-900"
                    : "bg-amber-100 text-amber-900"
                  : own
                    ? "text-sky-200"
                    : "text-sky-700"
              }`}
            >
              {segment.text}
            </span>
          );
        }

        // A reference is a link because that is the whole point of typing it:
        // "#Dichtungen" in a thread should get you to the work package.
        return (
          <Link
            key={index}
            href={`/projects/${projectId}/tasks/${segment.taskId}`}
            className={`rounded px-1 font-semibold underline underline-offset-2 ${
              own ? "text-sky-200" : "text-sky-700"
            }`}
          >
            {segment.text}
          </Link>
        );
      })}
    </p>
  );
}
