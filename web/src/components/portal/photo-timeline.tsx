"use client";

/* eslint-disable @next/next/no-img-element -- signed Supabase URLs */

import { useState } from "react";

import { Lightbox } from "@/components/chat/lightbox";
import { dayHeading, dayKey } from "@/lib/format";

export type TimelinePhoto = {
  id: string;
  url: string;
  annotated: boolean;
  caption: string | null;
  senderName: string | null;
  createdAt: string;
};

export function PhotoTimeline({ photos }: { photos: TimelinePhoto[] }) {
  const [lightbox, setLightbox] = useState<TimelinePhoto | null>(null);

  const days: { key: string; heading: string; items: TimelinePhoto[] }[] = [];
  for (const photo of photos) {
    const key = dayKey(photo.createdAt);
    const existing = days.find((d) => d.key === key);
    if (existing) existing.items.push(photo);
    else
      days.push({
        key,
        heading: dayHeading(photo.createdAt),
        items: [photo],
      });
  }

  return (
    <div className="space-y-8">
      {days.map((day) => (
        <div key={day.key}>
          <h3 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">
            {day.heading}
          </h3>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {day.items.map((photo) => (
              <figure key={photo.id}>
                <button
                  type="button"
                  onClick={() => setLightbox(photo)}
                  className="relative block w-full overflow-hidden rounded-xl bg-slate-200"
                >
                  <img
                    src={photo.url}
                    alt={photo.caption ?? "Progress photo"}
                    className="aspect-square w-full object-cover transition-transform hover:scale-[1.02]"
                    loading="lazy"
                  />
                  {photo.annotated && (
                    <span className="absolute left-2 top-2 rounded-full bg-slate-900/80 px-2 py-0.5 text-[10px] font-bold text-white">
                      ✏ Annotated
                    </span>
                  )}
                </button>
                {photo.caption && (
                  <figcaption className="mt-1.5 line-clamp-2 text-xs text-slate-600">
                    {photo.caption}
                  </figcaption>
                )}
              </figure>
            ))}
          </div>
        </div>
      ))}

      {lightbox && (
        <Lightbox
          url={lightbox.url}
          caption={lightbox.caption}
          onClose={() => setLightbox(null)}
        />
      )}
    </div>
  );
}
