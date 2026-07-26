"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";

import { Avatar } from "@/components/avatar";
import { RoleBadge } from "@/components/status-pill";
import { useTranslator } from "@/i18n/client";
import type { AppRole } from "@/lib/status";
import { createClient } from "@/lib/supabase/client";

const NAV = [
  { href: "/", labelKey: "nav.overview", icon: "▦" },
  { href: "/inbox", labelKey: "nav.inbox", icon: "💬" },
  { href: "/customers", labelKey: "nav.customers", icon: "🏠" },
  { href: "/people", labelKey: "nav.people", icon: "👥" },
  { href: "/export", labelKey: "nav.export", icon: "⤓" },
  { href: "/settings", labelKey: "nav.settings", icon: "⚙" },
] as const;

export function Sidebar({
  companyName,
  userName,
  role,
}: {
  companyName: string;
  userName: string;
  role: AppRole;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const t = useTranslator();
  const [open, setOpen] = useState(false);

  async function handleSignOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  function isActive(href: string) {
    if (href === "/") {
      return pathname === "/" || pathname.startsWith("/projects");
    }
    return pathname === href || pathname.startsWith(`${href}/`);
  }

  const nav = (
    <nav className="flex flex-col gap-1">
      {NAV.map((item) => (
        <Link
          key={item.href}
          href={item.href}
          onClick={() => setOpen(false)}
          className={`flex min-h-11 items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-semibold transition-colors ${
            isActive(item.href)
              ? "bg-slate-800 text-white"
              : "text-slate-300 hover:bg-slate-800/60 hover:text-white"
          }`}
        >
          <span aria-hidden className="w-5 text-center">
            {item.icon}
          </span>
          {t(item.labelKey)}
        </Link>
      ))}
    </nav>
  );

  const userBlock = (
    <div className="flex items-center gap-3 border-t border-slate-800 pt-4">
      <Avatar name={userName} />
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold text-white">{userName}</p>
        <RoleBadge role={role} />
      </div>
      <button
        type="button"
        onClick={handleSignOut}
        title={t("nav.signOut")}
        className="flex min-h-11 items-center rounded-lg px-2 text-xs font-semibold text-slate-400 hover:text-white"
      >
        {t("nav.signOut")}
      </button>
    </div>
  );

  return (
    <>
      {/* Mobile top bar */}
      <header className="sticky top-0 z-40 flex items-center justify-between gap-3 bg-slate-900 px-4 py-3 md:hidden">
        <Link href="/" className="flex items-center gap-2">
          <span className="flex size-8 items-center justify-center rounded-lg bg-white text-sm font-black text-slate-900">
            V
          </span>
          <span className="truncate text-sm font-bold text-white">
            {companyName}
          </span>
        </Link>
        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          aria-expanded={open}
          aria-label={t("nav.toggleMenu")}
          className="flex size-11 items-center justify-center rounded-lg text-white hover:bg-slate-800"
        >
          {open ? "✕" : "☰"}
        </button>
      </header>
      {open && (
        <div className="z-30 space-y-4 bg-slate-900 px-4 pb-4 md:hidden">
          {nav}
          {userBlock}
        </div>
      )}

      {/* Desktop sidebar */}
      <aside className="sticky top-0 hidden h-dvh w-64 shrink-0 flex-col bg-slate-900 p-4 md:flex">
        <Link href="/" className="mb-6 flex items-center gap-3 px-1">
          <span className="flex size-9 items-center justify-center rounded-lg bg-white text-base font-black text-slate-900">
            V
          </span>
          <span className="min-w-0">
            <span className="block text-sm font-black text-white">
              Ventline
            </span>
            <span className="block truncate text-xs text-slate-400">
              {companyName}
            </span>
          </span>
        </Link>
        <div className="flex-1">{nav}</div>
        {userBlock}
      </aside>
    </>
  );
}
