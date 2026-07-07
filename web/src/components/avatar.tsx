import { initials } from "@/lib/format";

const SIZES = {
  sm: "size-7 text-[10px]",
  md: "size-9 text-xs",
  lg: "size-11 text-sm",
} as const;

const COLORS = [
  "bg-slate-600",
  "bg-emerald-700",
  "bg-sky-700",
  "bg-amber-700",
  "bg-rose-700",
  "bg-violet-700",
  "bg-cyan-700",
  "bg-indigo-700",
];

function colorFor(seed: string): string {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) | 0;
  }
  return COLORS[Math.abs(hash) % COLORS.length];
}

export function Avatar({
  name,
  seed,
  size = "md",
}: {
  name: string;
  seed?: string;
  size?: keyof typeof SIZES;
}) {
  return (
    <span
      title={name}
      className={`inline-flex shrink-0 items-center justify-center rounded-full font-bold text-white ${SIZES[size]} ${colorFor(seed ?? name)}`}
    >
      {initials(name)}
    </span>
  );
}
