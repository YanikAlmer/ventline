/**
 * The Ventline mark: three stacked V's, the initial repeated so the repetition
 * itself reads as airflow.
 *
 * Same geometry as the app icon — see `scripts/build-app-icon.py`, which is
 * the source of truth for the proportions and the reasoning behind them. Kept
 * as inline SVG rather than an <img> so the lead chevron inherits colour from
 * wherever it is placed and the whole thing stays sharp at any size, and so
 * the two cannot drift apart by someone re-exporting one of them.
 *
 * The two lower chevrons carry fixed sky values rather than currentColor: the
 * descent through hue is the mark, and letting it inherit would collapse all
 * three into one flat shape.
 */
export function BrandMark({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 1024 1024"
      className={className}
      role="img"
      aria-label="Ventline"
      fill="none"
      strokeWidth={88}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M280 300 L512 482 L744 300" stroke="currentColor" />
      <path d="M280 436 L512 618 L744 436" stroke="#38BDF8" />
      <path d="M280 572 L512 754 L744 572" stroke="#0284C7" />
    </svg>
  );
}
