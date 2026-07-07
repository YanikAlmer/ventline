"use client";

import { formatDuration } from "@/lib/format";

export function VoicePlayer({
  url,
  waveform,
  durationSeconds,
}: {
  url: string | null;
  waveform: number[];
  durationSeconds: number | null;
}) {
  return (
    <div className="min-w-56 space-y-1.5">
      {waveform.length > 0 && (
        <div
          className="flex h-8 items-end gap-px"
          aria-hidden
          title={formatDuration(durationSeconds)}
        >
          {waveform.slice(0, 96).map((v, i) => (
            <span
              key={i}
              className="w-1 flex-1 rounded-sm bg-current opacity-60"
              style={{ height: `${Math.max(8, v * 100)}%` }}
            />
          ))}
        </div>
      )}
      {url ? (
        <audio controls preload="metadata" src={url} className="w-full max-w-72">
          Your browser does not support audio playback.
        </audio>
      ) : (
        <p className="text-xs opacity-70">Loading voice message…</p>
      )}
      <p className="text-xs opacity-70">
        Voice message · {formatDuration(durationSeconds)}
      </p>
    </div>
  );
}
