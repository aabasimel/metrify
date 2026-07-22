"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { useAuth } from "@/hooks/use-auth";

const sections = [
  {
    label: "Intelligence",
    items: [
      { href: "/dashboard", label: "Overview", icon: "◉" },
      { href: "/dashboard/margins", label: "Margins", icon: "◎" },
      { href: "/dashboard/usage", label: "Usage & Costs", icon: "◈" },
    ],
  },
  {
    label: "Compliance",
    items: [
      { href: "/dashboard/vat", label: "EU VAT", icon: "⬢" },
    ],
  },
];

export function Sidebar() {
  const pathname = usePathname();
  const { user, logout } = useAuth();

  const initials = user?.name
    ? user.name.split(" ").map((n) => n[0]).join("").toUpperCase().slice(0, 2)
    : "?";

  return (
    <aside className="w-[240px] flex flex-col border-r border-white/[0.04] bg-surface-1">
      {/* Logo */}
      <Link href="/" className="h-16 flex items-center gap-3 px-5 border-b border-white/[0.04] hover:bg-white/[0.02] transition-colors">
        <div className="h-7 w-7 rounded-lg bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center">
          <span className="text-white text-xs font-bold">M</span>
        </div>
        <div className="leading-none">
          <p className="text-sm font-bold text-zinc-100 tracking-tight">metrify</p>
          <p className="text-2xs text-zinc-600 mt-0.5">margin intelligence</p>
        </div>
      </Link>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-6 overflow-y-auto">
        {sections.map((section) => (
          <div key={section.label}>
            <p className="text-2xs font-semibold uppercase tracking-[0.15em] text-zinc-600 px-3 mb-2">{section.label}</p>
            <div className="space-y-0.5">
              {section.items.map((item) => {
                const active = pathname === item.href;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={cn(
                      "flex items-center gap-3 px-3 py-2 rounded-xl text-[13px] font-medium transition-all duration-150",
                      active
                        ? "bg-brand-600/10 text-brand-400"
                        : "text-zinc-500 hover:text-zinc-300 hover:bg-white/[0.04]"
                    )}
                  >
                    <span className={cn("text-sm", active ? "text-brand-400" : "text-zinc-600")}>{item.icon}</span>
                    {item.label}
                  </Link>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      {/* Bottom */}
      <div className="px-3 py-4 border-t border-white/[0.04] space-y-2">
        {/* Settings */}
        <Link
          href="/dashboard/settings"
          className={cn(
            "flex items-center gap-3 px-3 py-2 rounded-xl text-[13px] font-medium transition-all duration-150",
            pathname === "/dashboard/settings"
              ? "bg-brand-600/10 text-brand-400"
              : "text-zinc-500 hover:text-zinc-300 hover:bg-white/[0.04]"
          )}
        >
          <span className="text-sm text-zinc-600">⚙</span>
          Settings
        </Link>

        {/* User card */}
        <div className="mx-0 px-3 py-3 rounded-xl bg-white/[0.02] border border-white/[0.04]">
          <div className="flex items-center gap-3">
            {/* Avatar */}
            {user?.avatar ? (
              <img
                src={user.avatar}
                alt={user.name}
                className="h-8 w-8 rounded-lg object-cover"
              />
            ) : (
              <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-brand-500/20 to-purple-500/20 flex items-center justify-center border border-white/[0.06]">
                <span className="text-2xs font-bold text-brand-400">{initials}</span>
              </div>
            )}

            {/* Info */}
            <div className="flex-1 min-w-0">
              <p className="text-xs font-medium text-zinc-300 truncate">{user?.name || "User"}</p>
              <p className="text-2xs text-zinc-600 truncate">{user?.orgName || "Organization"}</p>
            </div>
          </div>

          {/* Sign out button */}
          <button
            onClick={logout}
            className="w-full mt-3 flex items-center justify-center gap-2 px-3 py-1.5 rounded-lg bg-white/[0.03] hover:bg-red-500/10 border border-white/[0.04] hover:border-red-500/20 text-2xs font-medium text-zinc-500 hover:text-red-400 transition-all"
          >
            <svg className="h-3 w-3" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9" />
            </svg>
            Sign out
          </button>
        </div>
      </div>
    </aside>
  );
}