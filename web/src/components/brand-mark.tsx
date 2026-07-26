/**
 * The Ventline mark: a V with air running into it.
 *
 * Same geometry as the app icon — see `scripts/build-app-icon.py`, which is
 * the source of truth for the proportions and the reasoning behind them. Kept
 * as inline SVG rather than an <img> so it inherits colour from wherever it is
 * placed and stays sharp at any size, and so the two never drift apart by
 * someone re-exporting one of them.
 *
 * Drawn without a tile: on the slate sidebar a dark tile would disappear and a
 * white one would shout. The mark alone is enough.
 */
export function BrandMark({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 1024 1024"
      className={className}
      role="img"
      aria-label="Ventline"
      fill="none"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path
        d="M421 322 L646 726 L871 322"
        stroke="currentColor"
        strokeWidth={118}
      />
      <g stroke="#38BDF8" strokeWidth={52}>
        <path d="M199 406 H343" />
        <path d="M153 524 H343" />
        <path d="M199 642 H343" />
      </g>
    </svg>
  );
}
