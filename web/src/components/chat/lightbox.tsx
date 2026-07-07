"use client";

/* eslint-disable @next/next/no-img-element -- signed Supabase URLs */

import { useEffect } from "react";

export function Lightbox({
  url,
  caption,
  onClose,
}: {
  url: string;
  caption: string | null;
  onClose: () => void;
}) {
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-slate-950/90 p-4"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label="Photo viewer"
    >
      <button
        type="button"
        onClick={onClose}
        aria-label="Close"
        className="absolute right-4 top-4 flex size-11 items-center justify-center rounded-full bg-white/10 text-lg text-white hover:bg-white/20"
      >
        ✕
      </button>
      <img
        src={url}
        alt={caption ?? "Photo"}
        className="max-h-[85dvh] max-w-full rounded-lg object-contain"
        onClick={(e) => e.stopPropagation()}
      />
      {caption && (
        <p className="mt-3 max-w-2xl text-center text-sm text-slate-200">
          {caption}
        </p>
      )}
    </div>
  );
}
