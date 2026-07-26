"use client";

/* eslint-disable @next/next/no-img-element -- signed Supabase URLs */

import { useI18n } from "@/i18n/client";
import { clockTime } from "@/lib/format";
import { localizeSystemBody } from "@/lib/system-messages";

import { MessageBody } from "./message-body";
import { displayPhoto, waveformBars, type ChatMessage } from "./types";
import { VoicePlayer } from "./voice-player";

export function MessageBubble({
  message,
  own,
  canDelete,
  urls,
  currentProfileId,
  onOpenPhoto,
  onDelete,
}: {
  message: ChatMessage;
  own: boolean;
  canDelete: boolean;
  urls: Map<string, string>;
  currentProfileId: string;
  onOpenPhoto: (url: string, caption: string | null) => void;
  onDelete: (messageId: string) => void;
}) {
  const { t, locale } = useI18n();

  if (message.kind === "system") {

    return (
      <div className="my-2 text-center text-xs text-slate-400">
        <span className="font-semibold">
          {message.sender?.full_name ?? t("chat.someone")}
        </span>{" "}
        {localizeSystemBody(message.body, t)}
      </div>
    );
  }

  const photoAttachments = message.attachments.filter(
    (a) => a.kind === "photo"
  );
  const voiceAttachments = message.attachments.filter(
    (a) => a.kind === "voice"
  );
  const videoAttachments = message.attachments.filter(
    (a) => a.kind === "video"
  );

  const bubbleClass = own
    ? "bg-slate-900 text-white"
    : "bg-white text-slate-900 ring-1 ring-inset ring-slate-200";

  return (
    <div className={`group flex ${own ? "justify-end" : "justify-start"}`}>
      <div className={`max-w-[85%] sm:max-w-[70%]`}>
        <div className={`rounded-2xl px-3.5 py-2.5 shadow-sm ${bubbleClass}`}>
          <div className="mb-0.5 flex items-baseline gap-2">
            <span
              className={`text-xs font-bold ${own ? "text-slate-300" : "text-slate-500"}`}
            >
              {own
                ? t("chat.you")
                : (message.sender?.full_name ?? t("chat.unknownSender"))}
            </span>
            <span
              className={`text-[10px] ${own ? "text-slate-400" : "text-slate-400"}`}
            >
              {clockTime(message.created_at, locale)}
            </span>
          </div>

          {photoAttachments.length > 0 && (
            <div
              className={`mb-1.5 grid gap-1.5 ${photoAttachments.length > 1 ? "grid-cols-2" : "grid-cols-1"}`}
            >
              {photoAttachments.map((att) => {
                const { path, annotated } = displayPhoto(att);
                const url = urls.get(path) ?? null;
                return (
                  <button
                    key={att.id}
                    type="button"
                    onClick={() =>
                      url && onOpenPhoto(url, message.body ?? null)
                    }
                    className="relative block overflow-hidden rounded-lg bg-slate-200"
                  >
                    {url ? (
                      <img
                        src={url}
                        alt={message.body ?? t("chat.photoAlt")}
                        className="max-h-64 w-full object-cover"
                        loading="lazy"
                      />
                    ) : (
                      <div className="flex h-32 w-40 items-center justify-center text-xs text-slate-500">
                        {t("common.loading")}
                      </div>
                    )}
                    {annotated && (
                      <span className="absolute left-1.5 top-1.5 rounded-full bg-slate-900/80 px-2 py-0.5 text-[10px] font-bold text-white">
                        ✏ {t("chat.annotated")}
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          )}

          {voiceAttachments.map((att) => (
            <VoicePlayer
              key={att.id}
              url={urls.get(att.storage_path) ?? null}
              waveform={waveformBars(att.waveform)}
              durationSeconds={att.duration_seconds}
            />
          ))}

          {videoAttachments.map((att) => {
            const url = urls.get(att.storage_path) ?? null;
            return url ? (
              <video
                key={att.id}
                controls
                preload="metadata"
                src={url}
                className="mb-1.5 max-h-64 w-full rounded-lg"
              />
            ) : (
              <p key={att.id} className="text-xs opacity-70">
                {t("chat.loadingVideo")}
              </p>
            );
          })}

          {message.body ? (
            <MessageBody
              body={message.body}
              mentions={message.message_mentions ?? []}
              refs={message.message_refs ?? []}
              projectId={message.project_id}
              currentProfileId={currentProfileId}
              own={own}
              // A caption under a photo is secondary to the photo.
              dim={message.kind !== "text"}
            />
          ) : null}
        </div>

        <div
          className={`mt-0.5 flex items-center gap-2 px-1 text-[10px] text-slate-400 ${own ? "justify-end" : "justify-start"}`}
        >
          {message.shared_with_customer && (
            <span className="font-semibold text-rose-500">
              {t("chat.sharedWithCustomer")}
            </span>
          )}
          {canDelete && (
            <button
              type="button"
              onClick={() => onDelete(message.id)}
              className="font-semibold text-slate-400 opacity-0 transition-opacity hover:text-red-600 focus:opacity-100 group-hover:opacity-100"
            >
              {t("common.delete")}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
