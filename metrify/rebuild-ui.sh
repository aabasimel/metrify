#!/bin/bash
set -e

# Run from metrify root
cd web

# Nuke everything and start fresh
rm -rf src
mkdir -p src/app/dashboard/margins
mkdir -p src/app/dashboard/usage
mkdir -p src/app/dashboard/billing
mkdir -p src/app/dashboard/vat
mkdir -p src/app/dashboard/settings
mkdir -p src/components/ui
mkdir -p src/components/charts
mkdir -p src/components/layout
mkdir -p src/hooks
mkdir -p src/lib
# ============================================
# TAILWIND CONFIG — proper design tokens
# ============================================
cat > tailwind.config.ts << 'EOF'
import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#eef2ff",
          100: "#e0e7ff",
          200: "#c7d2fe",
          300: "#a5b4fc",
          400: "#818cf8",
          500: "#6366f1",
          600: "#4f46e5",
          700: "#4338ca",
          800: "#3730a3",
          900: "#312e81",
          950: "#1e1b4b",
        },
        surface: {
          0: "#09090b",
          1: "#0c0c0f",
          2: "#111114",
          3: "#18181b",
          4: "#1f1f23",
          5: "#27272a",
        },
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "Fira Code", "monospace"],
      },
      fontSize: {
        "2xs": ["0.625rem", { lineHeight: "0.875rem" }],
      },
      animation: {
        "fade-in": "fadeIn 0.5s ease-out",
        "slide-up": "slideUp 0.5s ease-out",
        "slide-in-right": "slideInRight 0.3s ease-out",
        "pulse-slow": "pulse 3s ease-in-out infinite",
        "shimmer": "shimmer 2s linear infinite",
      },
      keyframes: {
        fadeIn: {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        slideUp: {
          "0%": { opacity: "0", transform: "translateY(10px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        slideInRight: {
          "0%": { opacity: "0", transform: "translateX(-10px)" },
          "100%": { opacity: "1", transform: "translateX(0)" },
        },
        shimmer: {
          "0%": { backgroundPosition: "-200% 0" },
          "100%": { backgroundPosition: "200% 0" },
        },
      },
    },
  },
  plugins: [],
};
export default config;
EOF

# ============================================
# GLOBAL CSS — refined
# ============================================
cat > src/app/globals.css << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap');

@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  * {
    @apply border-white/[0.06];
  }
  body {
    @apply bg-surface-0 text-zinc-100 antialiased;
    font-feature-settings: "cv02", "cv03", "cv04", "cv11";
  }
  ::selection {
    @apply bg-brand-500/30 text-white;
  }
}

@layer components {
  .glass {
    @apply bg-white/[0.03] backdrop-blur-xl border border-white/[0.06];
  }
  .glass-hover {
    @apply hover:bg-white/[0.05] hover:border-white/[0.1] transition-all duration-200;
  }
  .glow-brand {
    box-shadow: 0 0 20px -5px rgba(99, 102, 241, 0.15);
  }
  .glow-green {
    box-shadow: 0 0 20px -5px rgba(16, 185, 129, 0.15);
  }
  .glow-red {
    box-shadow: 0 0 20px -5px rgba(239, 68, 68, 0.15);
  }
  .text-gradient {
    @apply bg-clip-text text-transparent bg-gradient-to-r;
  }
}

/* Scrollbar */
::-webkit-scrollbar { width: 4px; height: 4px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.08); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.15); }

/* Recharts */
.recharts-cartesian-grid-horizontal line,
.recharts-cartesian-grid-vertical line { stroke: rgba(255,255,255,0.04); }
.recharts-text { fill: #52525b; font-size: 11px; }
.recharts-tooltip-cursor { stroke: rgba(255,255,255,0.06); }
EOF

# ============================================
# LIB/UTILS
# ============================================
cat > src/lib/utils.ts << 'EOF'
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCents(cents: number): string {
  const abs = Math.abs(cents);
  const formatted = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "EUR",
    minimumFractionDigits: abs >= 100000 ? 0 : 2,
    maximumFractionDigits: abs >= 100000 ? 0 : 2,
  }).format(cents / 100);
  return formatted;
}

export function formatPercent(value: number): string {
  return `${value >= 0 ? "" : ""}${value.toFixed(1)}%`;
}

export function formatNumber(value: number): string {
  return new Intl.NumberFormat("en-US").format(value);
}

export function formatCompact(value: number): string {
  if (value >= 1_000_000_000) return `${(value / 1_000_000_000).toFixed(1)}B`;
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`;
  return value.toString();
}

export function marginColor(m: number) {
  if (m >= 65) return { text: "text-emerald-400", bg: "bg-emerald-500/10 text-emerald-400 ring-emerald-500/20", dot: "#34d399" };
  if (m >= 40) return { text: "text-amber-400", bg: "bg-amber-500/10 text-amber-400 ring-amber-500/20", dot: "#fbbf24" };
  if (m >= 0) return { text: "text-orange-400", bg: "bg-orange-500/10 text-orange-400 ring-orange-500/20", dot: "#fb923c" };
  return { text: "text-red-400", bg: "bg-red-500/10 text-red-400 ring-red-500/20", dot: "#f87171" };
}

export function stagger(index: number, base: number = 50): string {
  return `${index * base}ms`;
}
EOF

cat > src/lib/api-client.ts << 'EOF'
const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

export async function api<T>(path: string, options: { method?: string; body?: unknown } = {}): Promise<T> {
  const { method = "GET", body } = options;
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}
EOF

# ============================================
# MOCK DATA
# ============================================
cat > src/lib/data.ts << 'EOF'
export const margins = {
  period_start: "2025-01-01",
  period_end: "2025-01-31",
  total_revenue_cents: 4850000,
  total_ai_cost_cents: 1420000,
  total_gross_profit_cents: 3430000,
  overall_margin_percent: 70.7,
  customer_count: 12,
  customers: [
    { id: "c1", name: "Acme Corp", ext: "acme_corp", revenue: 1200000, cost: 280000, profit: 920000, margin: 76.7 },
    { id: "c2", name: "Globex Inc", ext: "globex", revenue: 890000, cost: 310000, profit: 580000, margin: 65.2 },
    { id: "c3", name: "Initech GmbH", ext: "initech", revenue: 750000, cost: 190000, profit: 560000, margin: 74.7 },
    { id: "c4", name: "Hooli AG", ext: "hooli", revenue: 620000, cost: 180000, profit: 440000, margin: 71.0 },
    { id: "c5", name: "Pied Piper", ext: "piedpiper", revenue: 450000, cost: 120000, profit: 330000, margin: 73.3 },
    { id: "c6", name: "Wayne Enterprises", ext: "wayne", revenue: 380000, cost: 95000, profit: 285000, margin: 75.0 },
    { id: "c7", name: "Stark Industries", ext: "stark", revenue: 290000, cost: 85000, profit: 205000, margin: 70.7 },
    { id: "c8", name: "Umbrella Corp", ext: "umbrella", revenue: 120000, cost: 45000, profit: 75000, margin: 62.5 },
    { id: "c9", name: "Cyberdyne", ext: "cyberdyne", revenue: 85000, cost: 52000, profit: 33000, margin: 38.8 },
    { id: "c10", name: "Weyland-Yutani", ext: "weyland", revenue: 45000, cost: 38000, profit: 7000, margin: 15.6 },
    { id: "c11", name: "Skynet AI", ext: "skynet", revenue: 15000, cost: 22000, profit: -7000, margin: -46.7 },
    { id: "c12", name: "Trial User", ext: "trial", revenue: 5000, cost: 5000, profit: 0, margin: 0 },
  ],
  unprofitable: [
    { id: "c11", name: "Skynet AI", revenue: 15000, cost: 22000, profit: -7000, margin: -46.7 },
  ],
};

export const dailyRevenue = Array.from({ length: 31 }, (_, i) => {
  const base = 140000 + Math.sin(i * 0.5) * 40000;
  const weekend = (i % 7 === 5 || i % 7 === 6) ? 0.55 : 1;
  const growth = 1 + i * 0.008;
  const rev = Math.round(base * weekend * growth + (Math.random() - 0.5) * 15000);
  const cost = Math.round(rev * (0.27 + (Math.random() - 0.5) * 0.06));
  return { date: `Jan ${i + 1}`, revenue: rev, cost, profit: rev - cost };
});

export const costsByModel = [
  { provider: "OpenAI", model: "gpt-4o", cost: 680000, tokens: 12500000, pct: 47.9, color: "#818cf8" },
  { provider: "OpenAI", model: "gpt-4o-mini", cost: 285000, tokens: 45000000, pct: 20.1, color: "#a78bfa" },
  { provider: "Anthropic", model: "claude-3.5-sonnet", cost: 245000, tokens: 8200000, pct: 17.3, color: "#c084fc" },
  { provider: "OpenAI", model: "o1-mini", cost: 120000, tokens: 3800000, pct: 8.5, color: "#e879f9" },
  { provider: "Anthropic", model: "claude-3.5-haiku", cost: 55000, tokens: 6800000, pct: 3.9, color: "#f0abfc" },
  { provider: "OpenAI", model: "gpt-3.5-turbo", cost: 35000, tokens: 22000000, pct: 2.5, color: "#f5d0fe" },
];

export const usageByEvent = [
  { event: "ai_tokens", total: 28500000, billable: 24200000, revenue: 2420000, customers: 12 },
  { event: "document_processed", total: 45200, billable: 38900, revenue: 1167000, customers: 9 },
  { event: "api_calls", total: 892000, billable: 742000, revenue: 742000, customers: 12 },
  { event: "image_generated", total: 12800, billable: 11200, revenue: 336000, customers: 6 },
  { event: "embedding_created", total: 5200000, billable: 4800000, revenue: 144000, customers: 8 },
  { event: "speech_minutes", total: 8500, billable: 7200, revenue: 41000, customers: 3 },
];

export const usageTimeline = Array.from({ length: 15 }, (_, i) => ({
  date: `Jan ${i + 1}`,
  tokens: Math.round(800000 + Math.random() * 400000 + i * 15000),
  calls: Math.round(25000 + Math.random() * 12000 + i * 500),
  docs: Math.round(1000 + Math.random() * 600 + i * 30),
}));

export const pendingSync = [
  { customer: "Acme Corp", event: "ai_tokens", units: 2100000, amount: 210000 },
  { customer: "Acme Corp", event: "api_calls", units: 85000, amount: 85000 },
  { customer: "Globex Inc", event: "ai_tokens", units: 1800000, amount: 180000 },
  { customer: "Globex Inc", event: "document_processed", units: 4200, amount: 126000 },
  { customer: "Initech GmbH", event: "ai_tokens", units: 1500000, amount: 150000 },
  { customer: "Hooli AG", event: "ai_tokens", units: 1200000, amount: 120000 },
  { customer: "Hooli AG", event: "image_generated", units: 2800, amount: 84000 },
];

export const syncHistory = [
  { period: "January 2025", customers: 12, items: 18, amount: 4850000, date: "Feb 1, 2025" },
  { period: "December 2024", customers: 11, items: 16, amount: 4320000, date: "Jan 1, 2025" },
  { period: "November 2024", customers: 10, items: 15, amount: 3890000, date: "Dec 1, 2024" },
  { period: "October 2024", customers: 9, items: 14, amount: 3450000, date: "Nov 1, 2024" },
];

export const vatTransactions = [
  { customer: "Acme Corp", country: "DE", flag: "🇩🇪", treatment: "domestic", rate: 19, net: 1200000, vat: 228000, gross: 1428000, vatNum: "DE123456789" },
  { customer: "Globex Inc", country: "DE", flag: "🇩🇪", treatment: "domestic", rate: 19, net: 890000, vat: 169100, gross: 1059100, vatNum: "DE987654321" },
  { customer: "Initech GmbH", country: "DE", flag: "🇩🇪", treatment: "domestic", rate: 19, net: 750000, vat: 142500, gross: 892500, vatNum: "DE456789123" },
  { customer: "Hooli AG", country: "AT", flag: "🇦🇹", treatment: "reverse_charge", rate: 0, net: 620000, vat: 0, gross: 620000, vatNum: "ATU12345678" },
  { customer: "Pied Piper", country: "NL", flag: "🇳🇱", treatment: "reverse_charge", rate: 0, net: 450000, vat: 0, gross: 450000, vatNum: "NL123456789B01" },
  { customer: "Wayne Enterprises", country: "FR", flag: "🇫🇷", treatment: "oss", rate: 20, net: 380000, vat: 76000, gross: 456000, vatNum: null },
  { customer: "Stark Industries", country: "ES", flag: "🇪🇸", treatment: "oss", rate: 21, net: 290000, vat: 60900, gross: 350900, vatNum: null },
  { customer: "Umbrella Corp", country: "US", flag: "🇺🇸", treatment: "export", rate: 0, net: 120000, vat: 0, gross: 120000, vatNum: null },
  { customer: "Cyberdyne", country: "US", flag: "🇺🇸", treatment: "export", rate: 0, net: 85000, vat: 0, gross: 85000, vatNum: null },
  { customer: "Weyland-Yutani", country: "IE", flag: "🇮🇪", treatment: "reverse_charge", rate: 0, net: 45000, vat: 0, gross: 45000, vatNum: "IE1234567T" },
  { customer: "Skynet AI", country: "SE", flag: "🇸🇪", treatment: "oss", rate: 25, net: 15000, vat: 3750, gross: 18750, vatNum: null },
  { customer: "Trial User", country: "DE", flag: "🇩🇪", treatment: "domestic", rate: 19, net: 5000, vat: 950, gross: 5950, vatNum: null },
];
EOF

# ============================================
# UI COMPONENTS
# ============================================
cat > src/components/ui/metric-card.tsx << 'EOF'
"use client";
import { cn } from "@/lib/utils";
import { ReactNode } from "react";

interface MetricCardProps {
  label: string;
  value: string;
  subValue?: string;
  change?: { value: number; label: string };
  icon?: ReactNode;
  accent?: "brand" | "green" | "red" | "amber" | "default";
  className?: string;
  delay?: number;
}

const accents = {
  default: "from-white/[0.03] to-transparent",
  brand: "from-brand-500/[0.08] to-transparent",
  green: "from-emerald-500/[0.08] to-transparent",
  red: "from-red-500/[0.08] to-transparent",
  amber: "from-amber-500/[0.08] to-transparent",
};

const accentBorders = {
  default: "border-white/[0.06]",
  brand: "border-brand-500/20",
  green: "border-emerald-500/20",
  red: "border-red-500/20",
  amber: "border-amber-500/20",
};

export function MetricCard({ label, value, subValue, change, icon, accent = "default", className, delay = 0 }: MetricCardProps) {
  return (
    <div
      className={cn(
        "relative overflow-hidden rounded-2xl border p-5",
        "bg-gradient-to-b",
        accents[accent],
        accentBorders[accent],
        "animate-slide-up",
        className
      )}
      style={{ animationDelay: `${delay}ms`, animationFillMode: "both" }}
    >
      <div className="flex items-start justify-between">
        <div className="space-y-3">
          <p className="text-2xs font-semibold uppercase tracking-widest text-zinc-500">{label}</p>
          <p className="text-2xl font-bold tracking-tight">{value}</p>
          {subValue && <p className="text-xs text-zinc-500">{subValue}</p>}
          {change && (
            <div className="flex items-center gap-1.5">
              <span className={cn(
                "text-2xs font-semibold px-1.5 py-0.5 rounded-md",
                change.value >= 0 ? "bg-emerald-500/10 text-emerald-400" : "bg-red-500/10 text-red-400"
              )}>
                {change.value >= 0 ? "↑" : "↓"} {Math.abs(change.value)}%
              </span>
              <span className="text-2xs text-zinc-600">{change.label}</span>
            </div>
          )}
        </div>
        {icon && (
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/[0.04] text-zinc-500">
            {icon}
          </div>
        )}
      </div>
    </div>
  );
}
EOF

cat > src/components/ui/card.tsx << 'EOF'
import { cn } from "@/lib/utils";
import { ReactNode } from "react";

export function Card({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn("rounded-2xl border border-white/[0.06] bg-white/[0.02] overflow-hidden", className)}>
      {children}
    </div>
  );
}

export function CardHeader({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("px-6 py-5 border-b border-white/[0.04]", className)}>{children}</div>;
}

export function CardBody({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("p-6", className)}>{children}</div>;
}

export function CardTitle({ children, sub }: { children: ReactNode; sub?: string }) {
  return (
    <div>
      <h3 className="text-sm font-semibold text-zinc-200">{children}</h3>
      {sub && <p className="text-2xs text-zinc-500 mt-0.5">{sub}</p>}
    </div>
  );
}
EOF

cat > src/components/ui/badge.tsx << 'EOF'
import { cn } from "@/lib/utils";
import { ReactNode } from "react";

type Variant = "default" | "success" | "warning" | "danger" | "info" | "ghost";

const styles: Record<Variant, string> = {
  default: "bg-white/[0.06] text-zinc-400 ring-white/[0.06]",
  success: "bg-emerald-500/10 text-emerald-400 ring-emerald-500/20",
  warning: "bg-amber-500/10 text-amber-400 ring-amber-500/20",
  danger: "bg-red-500/10 text-red-400 ring-red-500/20",
  info: "bg-brand-500/10 text-brand-400 ring-brand-500/20",
  ghost: "bg-transparent text-zinc-500 ring-white/[0.06]",
};

export function Badge({ children, variant = "default", className }: { children: ReactNode; variant?: Variant; className?: string }) {
  return (
    <span className={cn("inline-flex items-center gap-1 rounded-lg px-2 py-0.5 text-2xs font-semibold ring-1 ring-inset", styles[variant], className)}>
      {children}
    </span>
  );
}
EOF

cat > src/components/ui/button.tsx << 'EOF'
import { cn } from "@/lib/utils";
import { ButtonHTMLAttributes, forwardRef } from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger";

const styles: Record<Variant, string> = {
  primary: "bg-brand-600 hover:bg-brand-500 text-white shadow-lg shadow-brand-600/10",
  secondary: "bg-white/[0.06] hover:bg-white/[0.1] text-zinc-300 ring-1 ring-inset ring-white/[0.08]",
  ghost: "hover:bg-white/[0.06] text-zinc-400 hover:text-zinc-200",
  danger: "bg-red-600/80 hover:bg-red-500 text-white",
};

export const Button = forwardRef<HTMLButtonElement, ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; size?: "sm" | "md" }>(
  ({ className, variant = "primary", size = "md", ...props }, ref) => (
    <button
      ref={ref}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-xl font-medium transition-all duration-200",
        "disabled:opacity-40 disabled:pointer-events-none",
        "active:scale-[0.98]",
        size === "sm" ? "px-3 py-1.5 text-xs" : "px-4 py-2 text-sm",
        styles[variant],
        className
      )}
      {...props}
    />
  )
);
Button.displayName = "Button";
EOF

cat > src/components/ui/table.tsx << 'EOF'
import { cn } from "@/lib/utils";
import { ReactNode } from "react";

export function Table({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">{children}</table>
    </div>
  );
}

export function THead({ children }: { children: ReactNode }) {
  return <thead>{children}</thead>;
}

export function TH({ children, className, align = "left" }: { children: ReactNode; className?: string; align?: "left" | "right" | "center" }) {
  return (
    <th className={cn(
      "px-5 py-3 text-2xs font-semibold uppercase tracking-widest text-zinc-600",
      align === "right" ? "text-right" : align === "center" ? "text-center" : "text-left",
      className
    )}>
      {children}
    </th>
  );
}

export function TBody({ children }: { children: ReactNode }) {
  return <tbody className="divide-y divide-white/[0.03]">{children}</tbody>;
}

export function TR({ children, className }: { children: ReactNode; className?: string }) {
  return <tr className={cn("hover:bg-white/[0.02] transition-colors", className)}>{children}</tr>;
}

export function TD({ children, className, align = "left", mono }: { children: ReactNode; className?: string; align?: "left" | "right" | "center"; mono?: boolean }) {
  return (
    <td className={cn(
      "px-5 py-4",
      align === "right" ? "text-right" : align === "center" ? "text-center" : "text-left",
      mono && "font-mono",
      className
    )}>
      {children}
    </td>
  );
}

export function TFoot({ children }: { children: ReactNode }) {
  return <tfoot className="border-t border-white/[0.08] bg-white/[0.02]">{children}</tfoot>;
}
EOF

# ============================================
# CHARTS
# ============================================
cat > src/components/charts/area-chart.tsx << 'EOF'
"use client";

import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";
import { formatCents } from "@/lib/utils";

function ChartTooltip({ active, payload, label }: any) {
  if (!active || !payload) return null;
  return (
    <div className="rounded-xl border border-white/[0.08] bg-surface-2 px-4 py-3 shadow-2xl">
      <p className="text-2xs font-medium text-zinc-500 mb-2">{label}</p>
      {payload.map((p: any) => (
        <div key={p.name} className="flex items-center justify-between gap-6 py-0.5">
          <div className="flex items-center gap-2">
            <div className="h-2 w-2 rounded-full" style={{ background: p.color }} />
            <span className="text-xs text-zinc-400">{p.name}</span>
          </div>
          <span className="text-xs font-semibold font-mono text-zinc-200">{formatCents(p.value)}</span>
        </div>
      ))}
    </div>
  );
}

interface Props {
  data: any[];
  areas: { key: string; name: string; color: string; gradient: string }[];
  height?: number;
}

export function MetrifyAreaChart({ data, areas, height = 320 }: Props) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
        <defs>
          {areas.map((a) => (
            <linearGradient key={a.key} id={`grad-${a.key}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={a.color} stopOpacity={0.15} />
              <stop offset="100%" stopColor={a.color} stopOpacity={0} />
            </linearGradient>
          ))}
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" vertical={false} />
        <XAxis dataKey="date" tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} />
        <YAxis tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} tickFormatter={(v) => `€${(v / 100).toFixed(0)}`} />
        <Tooltip content={<ChartTooltip />} />
        {areas.map((a) => (
          <Area key={a.key} type="monotone" dataKey={a.key} name={a.name} stroke={a.color} fill={`url(#grad-${a.key})`} strokeWidth={1.5} dot={false} />
        ))}
      </AreaChart>
    </ResponsiveContainer>
  );
}
EOF

cat > src/components/charts/bar-chart.tsx << 'EOF'
"use client";

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from "recharts";
import { formatPercent, marginColor } from "@/lib/utils";

function ChartTooltip({ active, payload }: any) {
  if (!active || !payload?.[0]) return null;
  const d = payload[0].payload;
  const mc = marginColor(d.margin);
  return (
    <div className="rounded-xl border border-white/[0.08] bg-surface-2 px-4 py-3 shadow-2xl">
      <p className="text-xs font-semibold text-zinc-200 mb-2">{d.name}</p>
      <div className="space-y-1 text-2xs">
        <div className="flex justify-between gap-6"><span className="text-zinc-500">Revenue</span><span className="font-mono text-emerald-400">€{(d.revenue / 100).toFixed(0)}</span></div>
        <div className="flex justify-between gap-6"><span className="text-zinc-500">AI Cost</span><span className="font-mono text-red-400">€{(d.cost / 100).toFixed(0)}</span></div>
        <div className="flex justify-between gap-6 pt-1 border-t border-white/[0.06]"><span className="text-zinc-500">Margin</span><span className={`font-mono font-semibold ${mc.text}`}>{formatPercent(d.margin)}</span></div>
      </div>
    </div>
  );
}

export function MarginBarChart({ data }: { data: any[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data} margin={{ top: 5, right: 5, left: -20, bottom: 60 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" vertical={false} />
        <XAxis dataKey="name" tick={{ fill: "#3f3f46", fontSize: 10 }} tickLine={false} axisLine={false} angle={-45} textAnchor="end" interval={0} />
        <YAxis tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} tickFormatter={(v) => `${v}%`} domain={[-60, 100]} />
        <Tooltip content={<ChartTooltip />} cursor={{ fill: "rgba(255,255,255,0.02)" }} />
        <Bar dataKey="margin" radius={[6, 6, 0, 0]} maxBarSize={32}>
          {data.map((d, i) => <Cell key={i} fill={marginColor(d.margin).dot} fillOpacity={0.8} />)}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
EOF

cat > src/components/charts/line-chart.tsx << 'EOF'
"use client";

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";
import { formatCompact } from "@/lib/utils";

function ChartTooltip({ active, payload, label }: any) {
  if (!active || !payload) return null;
  return (
    <div className="rounded-xl border border-white/[0.08] bg-surface-2 px-4 py-3 shadow-2xl">
      <p className="text-2xs font-medium text-zinc-500 mb-2">{label}</p>
      {payload.map((p: any) => (
        <div key={p.name} className="flex items-center justify-between gap-6 py-0.5">
          <div className="flex items-center gap-2">
            <div className="h-2 w-2 rounded-full" style={{ background: p.color }} />
            <span className="text-xs text-zinc-400">{p.name}</span>
          </div>
          <span className="text-xs font-semibold font-mono text-zinc-200">{formatCompact(p.value)}</span>
        </div>
      ))}
    </div>
  );
}

interface LineConfig { key: string; name: string; color: string }

export function MetrifyLineChart({ data, lines, height = 320 }: { data: any[]; lines: LineConfig[]; height?: number }) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={data} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" vertical={false} />
        <XAxis dataKey="date" tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} />
        <YAxis tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} tickFormatter={formatCompact} />
        <Tooltip content={<ChartTooltip />} />
        {lines.map((l) => <Line key={l.key} type="monotone" dataKey={l.key} name={l.name} stroke={l.color} strokeWidth={1.5} dot={false} />)}
      </LineChart>
    </ResponsiveContainer>
  );
}
EOF

cat > src/components/charts/donut-chart.tsx << 'EOF'
"use client";

import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from "recharts";
import { formatCents } from "@/lib/utils";

function ChartTooltip({ active, payload }: any) {
  if (!active || !payload?.[0]) return null;
  const d = payload[0].payload;
  return (
    <div className="rounded-xl border border-white/[0.08] bg-surface-2 px-4 py-3 shadow-2xl">
      <p className="text-xs font-semibold text-zinc-200">{d.model}</p>
      <p className="text-2xs text-zinc-500">{d.provider}</p>
      <p className="text-xs font-mono text-zinc-300 mt-1">{formatCents(d.cost)} · {d.pct}%</p>
    </div>
  );
}

export function DonutChart({ data, centerLabel, centerValue }: { data: any[]; centerLabel: string; centerValue: string }) {
  return (
    <div className="relative">
      <ResponsiveContainer width="100%" height={220}>
        <PieChart>
          <Pie data={data} cx="50%" cy="50%" innerRadius={65} outerRadius={90} dataKey="cost" stroke="none" paddingAngle={2}>
            {data.map((d, i) => <Cell key={i} fill={d.color} />)}
          </Pie>
          <Tooltip content={<ChartTooltip />} />
        </PieChart>
      </ResponsiveContainer>
      <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
        <p className="text-lg font-bold">{centerValue}</p>
        <p className="text-2xs text-zinc-500">{centerLabel}</p>
      </div>
    </div>
  );
}
EOF

# ============================================
# SIDEBAR
# ============================================
cat > src/components/layout/sidebar.tsx << 'EOF'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

const sections = [
  {
    label: "Analytics",
    items: [
      { href: "/dashboard", label: "Overview", icon: "◉" },
      { href: "/dashboard/margins", label: "Margins", icon: "◎" },
      { href: "/dashboard/usage", label: "Usage", icon: "◈" },
    ],
  },
  {
    label: "Billing",
    items: [
      { href: "/dashboard/billing", label: "Stripe Sync", icon: "⬡" },
      { href: "/dashboard/vat", label: "EU VAT", icon: "⬢" },
    ],
  },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-[240px] flex flex-col border-r border-white/[0.04] bg-surface-1">
      {/* Logo */}
      <div className="h-16 flex items-center gap-3 px-5 border-b border-white/[0.04]">
        <div className="h-7 w-7 rounded-lg bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center">
          <span className="text-white text-xs font-bold">M</span>
        </div>
        <div className="leading-none">
          <p className="text-sm font-bold text-zinc-100 tracking-tight">metrify</p>
          <p className="text-2xs text-zinc-600 mt-0.5">billing intelligence</p>
        </div>
      </div>

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

      {/* Footer */}
      <div className="px-3 py-4 border-t border-white/[0.04]">
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
        <div className="mt-3 mx-3 px-3 py-2.5 rounded-xl bg-white/[0.02] border border-white/[0.04]">
          <p className="text-xs font-medium text-zinc-400">Demo GmbH</p>
          <p className="text-2xs text-zinc-600 font-mono mt-0.5">mtfy_demo...4f2a</p>
        </div>
      </div>
    </aside>
  );
}
EOF

# ============================================
# APP SHELL
# ============================================
cat > src/app/providers.tsx << 'EOF'
"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  const [qc] = useState(() => new QueryClient());
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>;
}
EOF

cat > src/app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import "./globals.css";
import { Providers } from "./providers";

export const metadata: Metadata = {
  title: "Metrify — Billing Intelligence for AI",
  description: "Usage-based billing + cost intelligence for AI startups",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body><Providers>{children}</Providers></body>
    </html>
  );
}
EOF

cat > src/app/page.tsx << 'EOF'
import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center space-y-10 max-w-lg px-6">
        <div className="flex justify-center">
          <div className="h-14 w-14 rounded-2xl bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center shadow-xl shadow-brand-600/20">
            <span className="text-white text-xl font-bold">M</span>
          </div>
        </div>
        <div className="space-y-3">
          <h1 className="text-4xl font-bold tracking-tight">metrify</h1>
          <p className="text-base text-zinc-500 leading-relaxed">
            Usage-based billing and cost intelligence<br />for AI-native companies
          </p>
        </div>
        <Link
          href="/dashboard"
          className="inline-flex items-center gap-2 px-6 py-3 bg-brand-600 hover:bg-brand-500 rounded-xl font-medium text-sm transition-all shadow-lg shadow-brand-600/20 active:scale-[0.98]"
        >
          Open Dashboard →
        </Link>
      </div>
    </div>
  );
}
EOF

cat > src/app/dashboard/layout.tsx << 'EOF'
import { Sidebar } from "@/components/layout/sidebar";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="h-screen flex overflow-hidden">
      <Sidebar />
      <main className="flex-1 overflow-y-auto">
        <div className="max-w-[1400px] mx-auto px-8 py-8">{children}</div>
      </main>
    </div>
  );
}
EOF

# ============================================
# OVERVIEW PAGE
# ============================================
cat > src/app/dashboard/page.tsx << 'OVERVIEW'
"use client";

import { margins, dailyRevenue, costsByModel } from "@/lib/data";
import { formatCents, formatPercent, formatCompact, marginColor } from "@/lib/utils";
import { MetricCard } from "@/components/ui/metric-card";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { MetrifyAreaChart } from "@/components/charts/area-chart";
import { DonutChart } from "@/components/charts/donut-chart";

export default function OverviewPage() {
  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold tracking-tight">Overview</h1>
        <p className="text-xs text-zinc-500 mt-1">January 2025 · 12 active customers</p>
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-4 gap-4">
        <MetricCard label="Revenue" value={formatCents(margins.total_revenue_cents)} change={{ value: 12.3, label: "vs Dec" }} accent="green" delay={0} />
        <MetricCard label="AI Costs" value={formatCents(margins.total_ai_cost_cents)} subValue={`${formatPercent(margins.total_ai_cost_cents / margins.total_revenue_cents * 100)} of revenue`} change={{ value: 8.1, label: "vs Dec" }} accent="red" delay={50} />
        <MetricCard label="Gross Margin" value={formatPercent(margins.overall_margin_percent)} subValue={formatCents(margins.total_gross_profit_cents) + " profit"} change={{ value: 2.1, label: "vs Dec" }} accent="brand" delay={100} />
        <MetricCard label="Customers" value={String(margins.customer_count)} subValue={`${margins.unprofitable.length} unprofitable`} change={{ value: 9.1, label: "vs Dec" }} delay={150} />
      </div>

      {/* Revenue Chart */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle sub="Daily revenue and AI cost trend">Revenue vs AI Cost</CardTitle>
            <div className="flex items-center gap-4 text-2xs">
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-emerald-400" /><span className="text-zinc-500">Revenue</span></div>
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-red-400" /><span className="text-zinc-500">AI Cost</span></div>
            </div>
          </div>
        </CardHeader>
        <CardBody className="pt-2">
          <MetrifyAreaChart
            data={dailyRevenue}
            areas={[
              { key: "revenue", name: "Revenue", color: "#34d399", gradient: "emerald" },
              { key: "cost", name: "AI Cost", color: "#f87171", gradient: "red" },
            ]}
          />
        </CardBody>
      </Card>

      <div className="grid grid-cols-5 gap-6">
        {/* Cost Breakdown */}
        <Card className="col-span-2">
          <CardHeader>
            <CardTitle sub="Spend by model this period">AI Cost Breakdown</CardTitle>
          </CardHeader>
          <CardBody>
            <DonutChart data={costsByModel} centerLabel="total cost" centerValue={formatCents(margins.total_ai_cost_cents)} />
            <div className="mt-4 space-y-2">
              {costsByModel.map((m) => (
                <div key={m.model} className="flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2">
                    <div className="h-2.5 w-2.5 rounded" style={{ background: m.color }} />
                    <span className="text-zinc-400">{m.model}</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="font-mono text-zinc-500">{formatCents(m.cost)}</span>
                    <span className="text-2xs text-zinc-600 w-10 text-right">{m.pct}%</span>
                  </div>
                </div>
              ))}
            </div>
          </CardBody>
        </Card>

        {/* Top Customers */}
        <Card className="col-span-3">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle sub="Ranked by revenue">Top Customers</CardTitle>
              <Badge>{margins.customer_count} total</Badge>
            </div>
          </CardHeader>
          <div className="divide-y divide-white/[0.03]">
            {margins.customers.slice(0, 8).map((c, i) => {
              const mc = marginColor(c.margin);
              return (
                <div key={c.id} className="flex items-center justify-between px-6 py-3.5 hover:bg-white/[0.02] transition-colors">
                  <div className="flex items-center gap-3">
                    <span className="text-2xs text-zinc-700 font-mono w-4">{i + 1}</span>
                    <div className="h-7 w-7 rounded-lg bg-white/[0.04] flex items-center justify-center text-2xs font-bold text-zinc-500">
                      {c.name.charAt(0)}
                    </div>
                    <div>
                      <p className="text-[13px] font-medium text-zinc-300">{c.name}</p>
                      <p className="text-2xs text-zinc-600 font-mono">{formatCents(c.revenue)}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-2xs text-zinc-600 font-mono">cost {formatCents(c.cost)}</span>
                    <span className={`text-2xs font-semibold font-mono px-2 py-0.5 rounded-lg ring-1 ring-inset ${mc.bg}`}>
                      {formatPercent(c.margin)}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      </div>

      {/* Unprofitable Alert */}
      {margins.unprofitable.length > 0 && (
        <div className="rounded-2xl border border-red-500/20 bg-red-500/[0.04] p-5">
          <div className="flex items-center gap-2 mb-3">
            <div className="h-5 w-5 rounded-full bg-red-500/20 flex items-center justify-center">
              <span className="text-red-400 text-xs">!</span>
            </div>
            <p className="text-sm font-semibold text-red-400">{margins.unprofitable.length} customer losing money</p>
          </div>
          {margins.unprofitable.map((c) => (
            <div key={c.id} className="flex items-center justify-between bg-red-500/[0.04] rounded-xl px-4 py-3 mt-2">
              <div>
                <p className="text-sm font-medium text-zinc-300">{c.name}</p>
                <p className="text-2xs text-zinc-500 mt-0.5">Revenue {formatCents(c.revenue)} · Cost {formatCents(c.cost)} · Loss {formatCents(Math.abs(c.profit))}</p>
              </div>
              <Badge variant="danger">{formatPercent(c.margin)}</Badge>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
OVERVIEW

# ============================================
# MARGINS PAGE
# ============================================
cat > src/app/dashboard/margins/page.tsx << 'MARGINS'
"use client";

import { useState } from "react";
import { margins } from "@/lib/data";
import { formatCents, formatPercent, marginColor } from "@/lib/utils";
import { MetricCard } from "@/components/ui/metric-card";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { MarginBarChart } from "@/components/charts/bar-chart";
import { Table, THead, TH, TBody, TR, TD, TFoot } from "@/components/ui/table";

export default function MarginsPage() {
  const [sort, setSort] = useState<string>("revenue");

  const sorted = [...margins.customers].sort((a, b) => {
    if (sort === "margin_asc") return a.margin - b.margin;
    if (sort === "margin_desc") return b.margin - a.margin;
    if (sort === "cost") return b.cost - a.cost;
    return b.revenue - a.revenue;
  });

  const healthy = margins.customers.filter(c => c.margin >= 50).length;
  const warning = margins.customers.filter(c => c.margin >= 0 && c.margin < 50).length;
  const danger = margins.customers.filter(c => c.margin < 0).length;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-xl font-bold tracking-tight">Margin Analysis</h1>
        <p className="text-xs text-zinc-500 mt-1">Per-customer profitability · January 2025</p>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <MetricCard label="Overall Margin" value={formatPercent(margins.overall_margin_percent)} subValue={formatCents(margins.total_gross_profit_cents) + " profit"} accent="brand" delay={0} />
        <MetricCard label="Healthy (≥50%)" value={String(healthy)} subValue={`${((healthy / margins.customer_count) * 100).toFixed(0)}% of customers`} accent="green" delay={50} />
        <MetricCard label="Warning (0–50%)" value={String(warning)} subValue="Review pricing" accent="amber" delay={100} />
        <MetricCard label="Unprofitable (<0%)" value={String(danger)} subValue="Action needed" accent="red" delay={150} />
      </div>

      <Card>
        <CardHeader><CardTitle sub="Margin percentage by customer — red indicates loss">Margin Distribution</CardTitle></CardHeader>
        <CardBody className="pt-2"><MarginBarChart data={sorted} /></CardBody>
      </Card>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle sub={`${margins.customer_count} customers · ${margins.period_start} to ${margins.period_end}`}>Customer Detail</CardTitle>
            <select
              value={sort}
              onChange={(e) => setSort(e.target.value)}
              className="bg-white/[0.04] border border-white/[0.08] rounded-xl px-3 py-1.5 text-xs text-zinc-400 focus:outline-none focus:ring-1 focus:ring-brand-500/50"
            >
              <option value="revenue">Sort: Revenue</option>
              <option value="margin_desc">Sort: Margin ↓</option>
              <option value="margin_asc">Sort: Margin ↑</option>
              <option value="cost">Sort: AI Cost</option>
            </select>
          </div>
        </CardHeader>
        <Table>
          <THead>
            <tr className="border-b border-white/[0.04]">
              <TH>#</TH><TH>Customer</TH><TH align="right">Revenue</TH><TH align="right">AI Cost</TH><TH align="right">Profit</TH><TH align="right">Margin</TH><TH align="right">Status</TH>
            </tr>
          </THead>
          <TBody>
            {sorted.map((c, i) => {
              const mc = marginColor(c.margin);
              return (
                <TR key={c.id}>
                  <TD className="text-zinc-700 font-mono text-2xs">{i + 1}</TD>
                  <TD>
                    <div className="flex items-center gap-3">
                      <div className="h-7 w-7 rounded-lg bg-white/[0.04] flex items-center justify-center text-2xs font-bold text-zinc-500">{c.name.charAt(0)}</div>
                      <div>
                        <p className="text-[13px] font-medium text-zinc-200">{c.name}</p>
                        <p className="text-2xs text-zinc-600 font-mono">{c.ext}</p>
                      </div>
                    </div>
                  </TD>
                  <TD align="right" mono className="text-emerald-400">{formatCents(c.revenue)}</TD>
                  <TD align="right" mono className="text-red-400">{formatCents(c.cost)}</TD>
                  <TD align="right" mono className={c.profit >= 0 ? "text-emerald-400" : "text-red-400"}>{formatCents(c.profit)}</TD>
                  <TD align="right">
                    <span className={`text-2xs font-semibold font-mono px-2 py-0.5 rounded-lg ring-1 ring-inset ${mc.bg}`}>{formatPercent(c.margin)}</span>
                  </TD>
                  <TD align="right">
                    {c.margin >= 50 ? <Badge variant="success">Healthy</Badge> : c.margin >= 0 ? <Badge variant="warning">Warning</Badge> : <Badge variant="danger">Loss</Badge>}
                  </TD>
                </TR>
              );
            })}
          </TBody>
          <TFoot>
            <tr>
              <TD colSpan={2} className="font-semibold text-zinc-300">Total ({margins.customer_count})</TD>
              <TD align="right" mono className="text-emerald-400 font-semibold">{formatCents(margins.total_revenue_cents)}</TD>
              <TD align="right" mono className="text-red-400 font-semibold">{formatCents(margins.total_ai_cost_cents)}</TD>
              <TD align="right" mono className="text-emerald-400 font-semibold">{formatCents(margins.total_gross_profit_cents)}</TD>
              <TD align="right"><span className={`text-2xs font-semibold font-mono px-2 py-0.5 rounded-lg ring-1 ring-inset ${marginColor(margins.overall_margin_percent).bg}`}>{formatPercent(margins.overall_margin_percent)}</span></TD>
              <TD></TD>
            </tr>
          </TFoot>
        </Table>
      </Card>
    </div>
  );
}
MARGINS

# ============================================
# USAGE PAGE
# ============================================
cat > src/app/dashboard/usage/page.tsx << 'USAGE'
"use client";

import { usageByEvent, usageTimeline } from "@/lib/data";
import { formatCents, formatCompact } from "@/lib/utils";
import { MetricCard } from "@/components/ui/metric-card";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { MetrifyLineChart } from "@/components/charts/line-chart";
import { Table, THead, TH, TBody, TR, TD, TFoot } from "@/components/ui/table";

export default function UsagePage() {
  const totalUnits = usageByEvent.reduce((s, e) => s + e.total, 0);
  const totalBillable = usageByEvent.reduce((s, e) => s + e.billable, 0);
  const totalRevenue = usageByEvent.reduce((s, e) => s + e.revenue, 0);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-xl font-bold tracking-tight">Usage Analytics</h1>
        <p className="text-xs text-zinc-500 mt-1">Event tracking and billable usage · January 2025</p>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <MetricCard label="Total Events" value={formatCompact(totalUnits)} subValue={`${usageByEvent.length} event types`} delay={0} />
        <MetricCard label="Billable Units" value={formatCompact(totalBillable)} subValue={`${((totalBillable / totalUnits) * 100).toFixed(1)}% billable`} accent="brand" delay={50} />
        <MetricCard label="Usage Revenue" value={formatCents(totalRevenue)} subValue="From metered billing" accent="green" delay={100} />
        <MetricCard label="Avg / Customer" value={formatCents(Math.round(totalRevenue / 12))} subValue="12 active customers" delay={150} />
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle sub="Daily event volume by type">Usage Timeline</CardTitle>
            <div className="flex items-center gap-4 text-2xs">
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-brand-400" /><span className="text-zinc-500">Tokens</span></div>
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-violet-400" /><span className="text-zinc-500">API Calls</span></div>
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-cyan-400" /><span className="text-zinc-500">Documents</span></div>
            </div>
          </div>
        </CardHeader>
        <CardBody className="pt-2">
          <MetrifyLineChart
            data={usageTimeline}
            lines={[
              { key: "tokens", name: "AI Tokens", color: "#818cf8" },
              { key: "calls", name: "API Calls", color: "#a78bfa" },
              { key: "docs", name: "Documents", color: "#22d3ee" },
            ]}
          />
        </CardBody>
      </Card>

      <Card>
        <CardHeader><CardTitle sub="All tracked events and billing impact">Events Breakdown</CardTitle></CardHeader>
        <Table>
          <THead>
            <tr className="border-b border-white/[0.04]">
              <TH>Event</TH><TH align="right">Total</TH><TH align="right">Billable</TH><TH align="right">Revenue</TH><TH align="right">Customers</TH><TH>Share</TH>
            </tr>
          </THead>
          <TBody>
            {usageByEvent.map((e) => {
              const share = (e.revenue / totalRevenue) * 100;
              return (
                <TR key={e.event}>
                  <TD><code className="text-xs font-mono text-brand-400 bg-brand-500/10 px-2 py-0.5 rounded-lg">{e.event}</code></TD>
                  <TD align="right" mono className="text-zinc-400">{formatCompact(e.total)}</TD>
                  <TD align="right" mono className="text-zinc-300">{formatCompact(e.billable)} <span className="text-zinc-600 text-2xs">({((e.billable / e.total) * 100).toFixed(0)}%)</span></TD>
                  <TD align="right" mono className="text-emerald-400">{formatCents(e.revenue)}</TD>
                  <TD align="right" className="text-zinc-500">{e.customers}</TD>
                  <TD>
                    <div className="flex items-center gap-2">
                      <div className="flex-1 h-1.5 bg-white/[0.04] rounded-full overflow-hidden">
                        <div className="h-full bg-brand-500/60 rounded-full" style={{ width: `${share}%` }} />
                      </div>
                      <span className="text-2xs text-zinc-600 w-10 text-right font-mono">{share.toFixed(1)}%</span>
                    </div>
                  </TD>
                </TR>
              );
            })}
          </TBody>
          <TFoot>
            <tr>
              <TD className="font-semibold text-zinc-300">Total</TD>
              <TD align="right" mono className="font-semibold">{formatCompact(totalUnits)}</TD>
              <TD align="right" mono className="font-semibold">{formatCompact(totalBillable)}</TD>
              <TD align="right" mono className="text-emerald-400 font-semibold">{formatCents(totalRevenue)}</TD>
              <TD align="right" className="text-zinc-500">12</TD>
              <TD></TD>
            </tr>
          </TFoot>
        </Table>
      </Card>
    </div>
  );
}
USAGE

# ============================================
# BILLING PAGE
# ============================================
cat > src/app/dashboard/billing/page.tsx << 'BILLING'
"use client";

import { useState } from "react";
import { pendingSync, syncHistory } from "@/lib/data";
import { formatCents } from "@/lib/utils";
import { MetricCard } from "@/components/ui/metric-card";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Table, THead, TH, TBody, TR, TD, TFoot } from "@/components/ui/table";

export default function BillingPage() {
  const [syncing, setSyncing] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const total = pendingSync.reduce((s, p) => s + p.amount, 0);
  const customers = new Set(pendingSync.map(p => p.customer)).size;

  return (
    <div className="space-y-8">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-xl font-bold tracking-tight">Billing & Stripe Sync</h1>
          <p className="text-xs text-zinc-500 mt-1">Aggregate usage and push to Stripe</p>
        </div>
        <Button onClick={() => setConfirm(true)} disabled={syncing}>
          {syncing ? "Syncing…" : "Sync to Stripe →"}
        </Button>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <MetricCard label="Pending" value={formatCents(total)} subValue={`${customers} customers · ${pendingSync.length} items`} accent="amber" delay={0} />
        <MetricCard label="Last Sync" value="Feb 1" subValue="12 customers synced" delay={50} />
        <MetricCard label="YTD Synced" value={formatCents(syncHistory.reduce((s, h) => s + h.amount, 0))} subValue={`${syncHistory.length} periods`} accent="green" delay={100} />
        <MetricCard label="Stripe" value="Connected" subValue="sk_live_...4f2a" accent="brand" delay={150} />
      </div>

      {confirm && (
        <div className="rounded-2xl border border-brand-500/20 bg-brand-500/[0.04] p-5 animate-fade-in">
          <div className="flex items-start justify-between">
            <div>
              <p className="text-sm font-semibold text-brand-400">Confirm Stripe Sync</p>
              <p className="text-xs text-zinc-400 mt-1">{pendingSync.length} line items for {customers} customers · {formatCents(total)}</p>
            </div>
            <div className="flex gap-2">
              <Button variant="ghost" size="sm" onClick={() => setConfirm(false)}>Cancel</Button>
              <Button size="sm" onClick={() => { setSyncing(true); setTimeout(() => { setSyncing(false); setConfirm(false); }, 2000); }}>
                {syncing ? "Syncing…" : "Confirm"}
              </Button>
            </div>
          </div>
        </div>
      )}

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle sub="Aggregated and ready for Stripe">Pending Line Items</CardTitle>
            <Badge variant="warning">{pendingSync.length} pending</Badge>
          </div>
        </CardHeader>
        <Table>
          <THead><tr className="border-b border-white/[0.04]"><TH>Customer</TH><TH>Event</TH><TH align="right">Units</TH><TH align="right">Amount</TH></tr></THead>
          <TBody>
            {pendingSync.map((p, i) => (
              <TR key={i}>
                <TD className="font-medium text-zinc-300">{p.customer}</TD>
                <TD><code className="text-xs font-mono text-brand-400 bg-brand-500/10 px-2 py-0.5 rounded-lg">{p.event}</code></TD>
                <TD align="right" mono className="text-zinc-400">{p.units.toLocaleString()}</TD>
                <TD align="right" mono className="text-emerald-400">{formatCents(p.amount)}</TD>
              </TR>
            ))}
          </TBody>
          <TFoot><tr><TD colSpan={3} className="font-semibold text-zinc-300">Total</TD><TD align="right" mono className="text-emerald-400 font-semibold">{formatCents(total)}</TD></tr></TFoot>
        </Table>
      </Card>

      <Card>
        <CardHeader><CardTitle sub="Previous billing syncs">Sync History</CardTitle></CardHeader>
        <Table>
          <THead><tr className="border-b border-white/[0.04]"><TH>Period</TH><TH>Status</TH><TH align="right">Customers</TH><TH align="right">Items</TH><TH align="right">Amount</TH><TH align="right">Date</TH></tr></THead>
          <TBody>
            {syncHistory.map((h, i) => (
              <TR key={i}>
                <TD className="font-medium text-zinc-300">{h.period}</TD>
                <TD><Badge variant="success">Synced</Badge></TD>
                <TD align="right" className="text-zinc-400">{h.customers}</TD>
                <TD align="right" className="text-zinc-400">{h.items}</TD>
                <TD align="right" mono className="text-emerald-400">{formatCents(h.amount)}</TD>
                <TD align="right" className="text-zinc-600 text-xs">{h.date}</TD>
              </TR>
            ))}
          </TBody>
        </Table>
      </Card>
    </div>
  );
}
BILLING

# ============================================
# VAT PAGE
# ============================================
cat > src/app/dashboard/vat/page.tsx << 'VAT'
"use client";

import { vatTransactions } from "@/lib/data";
import { formatCents, formatPercent } from "@/lib/utils";
import { MetricCard } from "@/components/ui/metric-card";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Table, THead, TH, TBody, TR, TD, TFoot } from "@/components/ui/table";

const treatmentLabel: Record<string, string> = { domestic: "Domestic", reverse_charge: "Reverse Charge", oss: "EU OSS", export: "Export" };
const treatmentVariant: Record<string, "default" | "info" | "warning" | "success"> = { domestic: "default", reverse_charge: "info", oss: "warning", export: "success" };

export default function VATPage() {
  const totalVAT = vatTransactions.reduce((s, t) => s + t.vat, 0);
  const totalNet = vatTransactions.reduce((s, t) => s + t.net, 0);
  const domestic = vatTransactions.filter(t => t.treatment === "domestic");
  const rc = vatTransactions.filter(t => t.treatment === "reverse_charge");
  const oss = vatTransactions.filter(t => t.treatment === "oss");
  const exp = vatTransactions.filter(t => t.treatment === "export");

  const ossTotal = 685000;
  const ossThreshold = 1000000;
  const ossPct = (ossTotal / ossThreshold) * 100;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-xl font-bold tracking-tight">EU VAT Management</h1>
        <p className="text-xs text-zinc-500 mt-1">Tax compliance, OSS tracking, and calculations</p>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <MetricCard label="VAT Collected" value={formatCents(totalVAT)} subValue={`${formatPercent(totalVAT / totalNet * 100)} effective rate`} accent="amber" delay={0} />
        <MetricCard label="Domestic (DE)" value={formatCents(domestic.reduce((s, t) => s + t.vat, 0))} subValue={`${domestic.length} transactions · 19%`} delay={50} />
        <MetricCard label="EU OSS" value={formatCents(oss.reduce((s, t) => s + t.vat, 0))} subValue={`${oss.length} B2C transactions`} delay={100} />
        <MetricCard label="Reverse Charge" value={`${rc.length} invoices`} subValue="€0 VAT — buyer accounts" delay={150} />
      </div>

      {/* OSS Threshold */}
      <Card className={ossPct >= 80 ? "border-amber-500/20" : ""}>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle sub="€10,000 annual threshold for cross-border B2C">OSS Threshold</CardTitle>
            {ossPct >= 80 ? <Badge variant="warning">Approaching</Badge> : <Badge variant="success">Below</Badge>}
          </div>
        </CardHeader>
        <CardBody>
          <div className="space-y-4">
            <div>
              <div className="flex justify-between text-xs mb-2">
                <span className="text-zinc-500">Cross-border EU B2C (YTD)</span>
                <span className="font-mono text-zinc-300">{formatCents(ossTotal)} / {formatCents(ossThreshold)}</span>
              </div>
              <div className="h-2 bg-white/[0.04] rounded-full overflow-hidden">
                <div className={`h-full rounded-full transition-all duration-1000 ${ossPct >= 80 ? "bg-amber-500" : "bg-brand-500"}`} style={{ width: `${ossPct}%` }} />
              </div>
              <p className="text-2xs text-zinc-600 mt-1">{ossPct.toFixed(1)}% of threshold</p>
            </div>
            <p className="text-xs text-zinc-500">You are at {ossPct.toFixed(1)}% of the OSS threshold. Monitor closely as you approach €10,000 in cross-border EU B2C sales.</p>
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-2xs text-zinc-600">Countries:</span>
              {["🇫🇷 FR", "🇪🇸 ES", "🇸🇪 SE", "🇳🇱 NL", "🇦🇹 AT", "🇮🇪 IE"].map(c => (
                <span key={c} className="text-xs bg-white/[0.04] px-2 py-0.5 rounded-lg text-zinc-400">{c}</span>
              ))}
            </div>
          </div>
        </CardBody>
      </Card>

      {/* Treatment Summary */}
      <div className="grid grid-cols-4 gap-4">
        {[
          { label: "Domestic", data: domestic, variant: "default" as const },
          { label: "Reverse Charge", data: rc, variant: "info" as const },
          { label: "EU OSS", data: oss, variant: "warning" as const },
          { label: "Export", data: exp, variant: "success" as const },
        ].map((g) => (
          <Card key={g.label} className="hover:border-white/[0.1] transition-colors">
            <CardBody>
              <Badge variant={g.variant} className="mb-3">{g.label}</Badge>
              <p className="text-xl font-bold">{formatCents(g.data.reduce((s, t) => s + t.net, 0))}</p>
              <p className="text-2xs text-zinc-500 mt-1">{g.data.length} transactions</p>
              {g.data.reduce((s, t) => s + t.vat, 0) > 0 && (
                <p className="text-2xs text-zinc-600 mt-0.5">VAT: {formatCents(g.data.reduce((s, t) => s + t.vat, 0))}</p>
              )}
            </CardBody>
          </Card>
        ))}
      </div>

      {/* Transactions */}
      <Card>
        <CardHeader><CardTitle sub="Per-customer VAT treatment">Transactions</CardTitle></CardHeader>
        <Table>
          <THead>
            <tr className="border-b border-white/[0.04]">
              <TH>Customer</TH><TH>Country</TH><TH>Treatment</TH><TH align="right">Rate</TH><TH align="right">Net</TH><TH align="right">VAT</TH><TH align="right">Gross</TH><TH>VAT Number</TH>
            </tr>
          </THead>
          <TBody>
            {vatTransactions.map((t, i) => (
              <TR key={i}>
                <TD className="font-medium text-zinc-300">{t.customer}</TD>
                <TD><span className="mr-1">{t.flag}</span><span className="text-zinc-500">{t.country}</span></TD>
                <TD><Badge variant={treatmentVariant[t.treatment]}>{treatmentLabel[t.treatment]}</Badge></TD>
                <TD align="right" mono className="text-zinc-400">{t.rate > 0 ? `${t.rate}%` : "—"}</TD>
                <TD align="right" mono className="text-zinc-300">{formatCents(t.net)}</TD>
                <TD align="right" mono>{t.vat > 0 ? <span className="text-amber-400">{formatCents(t.vat)}</span> : <span className="text-zinc-700">—</span>}</TD>
                <TD align="right" mono className="text-zinc-200">{formatCents(t.gross)}</TD>
                <TD className="text-2xs font-mono text-zinc-600">{t.vatNum || "—"}</TD>
              </TR>
            ))}
          </TBody>
          <TFoot>
            <tr>
              <TD colSpan={4} className="font-semibold text-zinc-300">Total</TD>
              <TD align="right" mono className="font-semibold">{formatCents(totalNet)}</TD>
              <TD align="right" mono className="text-amber-400 font-semibold">{formatCents(totalVAT)}</TD>
              <TD align="right" mono className="font-semibold">{formatCents(vatTransactions.reduce((s, t) => s + t.gross, 0))}</TD>
              <TD></TD>
            </tr>
          </TFoot>
        </Table>
      </Card>
    </div>
  );
}
VAT

# ============================================
# SETTINGS PAGE
# ============================================
cat > src/app/dashboard/settings/page.tsx << 'SETTINGS'
"use client";

import { useState } from "react";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

export default function SettingsPage() {
  const [copied, setCopied] = useState<string | null>(null);
  const copy = (key: string, val: string) => { navigator.clipboard.writeText(val); setCopied(key); setTimeout(() => setCopied(null), 2000); };

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-xl font-bold tracking-tight">Settings</h1>
        <p className="text-xs text-zinc-500 mt-1">API keys, integrations, and organization config</p>
      </div>

      <Card>
        <CardHeader><CardTitle sub="Authenticate SDK and API requests">API Keys</CardTitle></CardHeader>
        <CardBody className="space-y-3">
          {[
            { label: "Live", key: "live", value: "mtfy_live_sk_a1b2c3d4e5f6g7h8i9j0" },
            { label: "Test", key: "test", value: "mtfy_test_sk_x9y8w7v6u5t4s3r2q1p0" },
          ].map((k) => (
            <div key={k.key} className="flex items-center justify-between bg-white/[0.03] rounded-xl px-4 py-3 border border-white/[0.04]">
              <div>
                <p className="text-2xs text-zinc-500 font-semibold uppercase tracking-wider">{k.label} Key</p>
                <code className="text-xs font-mono text-zinc-400 mt-0.5">{k.value.slice(0, 20)}...{k.value.slice(-4)}</code>
              </div>
              <Button variant="secondary" size="sm" onClick={() => copy(k.key, k.value)}>
                {copied === k.key ? "Copied ✓" : "Copy"}
              </Button>
            </div>
          ))}
        </CardBody>
      </Card>

      <div className="grid grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle sub="Billing sync connection">Stripe</CardTitle>
              <Badge variant="success">Connected</Badge>
            </div>
          </CardHeader>
          <CardBody>
            <div className="grid grid-cols-2 gap-4 text-xs">
              <div><p className="text-zinc-600">Account</p><p className="font-mono text-zinc-400 mt-0.5">acct_1N2x...8d</p></div>
              <div><p className="text-zinc-600">Currency</p><p className="text-zinc-400 mt-0.5">EUR (€)</p></div>
              <div><p className="text-zinc-600">Webhook</p><p className="text-emerald-400 mt-0.5">Active</p></div>
              <div><p className="text-zinc-600">Last event</p><p className="text-zinc-400 mt-0.5">2 min ago</p></div>
            </div>
          </CardBody>
        </Card>

        <Card>
          <CardHeader><CardTitle sub="For automatic cost attribution">AI Providers</CardTitle></CardHeader>
          <CardBody className="space-y-3">
            {[
              { name: "OpenAI", key: "sk-proj-...8f2a" },
              { name: "Anthropic", key: "sk-ant-...3d1b" },
            ].map((p) => (
              <div key={p.name} className="flex items-center justify-between bg-white/[0.03] rounded-xl px-4 py-2.5 border border-white/[0.04]">
                <div className="flex items-center gap-2">
                  <div className="h-2 w-2 rounded-full bg-emerald-400" />
                  <span className="text-xs font-medium text-zinc-300">{p.name}</span>
                  <span className="text-2xs font-mono text-zinc-600">{p.key}</span>
                </div>
                <Badge variant="success">Active</Badge>
              </div>
            ))}
          </CardBody>
        </Card>
      </div>

      <Card>
        <CardHeader><CardTitle sub="Business details for VAT">Organization</CardTitle></CardHeader>
        <CardBody>
          <div className="grid grid-cols-4 gap-6 text-xs">
            <div><p className="text-zinc-600">Company</p><p className="text-zinc-300 mt-0.5">Demo GmbH</p></div>
            <div><p className="text-zinc-600">Country</p><p className="text-zinc-300 mt-0.5">🇩🇪 Germany</p></div>
            <div><p className="text-zinc-600">VAT Number</p><p className="font-mono text-zinc-300 mt-0.5">DE123456789</p></div>
            <div><p className="text-zinc-600">OSS</p><p className="text-emerald-400 mt-0.5">Registered</p></div>
          </div>
        </CardBody>
      </Card>

      <Card>
        <CardHeader><CardTitle sub="Add usage tracking in 2 minutes">Quick Start</CardTitle></CardHeader>
        <CardBody className="space-y-3">
          <div className="bg-surface-2 rounded-xl p-4 border border-white/[0.04] overflow-x-auto">
            <pre className="text-xs font-mono text-zinc-400 leading-relaxed"><span className="text-zinc-600"># Python</span>{"\n"}pip install metrify{"\n\n"}<span className="text-brand-400">from</span> metrify <span className="text-brand-400">import</span> Metrify{"\n"}m = Metrify(api_key=<span className="text-emerald-400">&quot;mtfy_live_sk_...&quot;</span>){"\n\n"}m.track(<span className="text-emerald-400">&quot;ai_tokens&quot;</span>,{"\n"}    customer_id=<span className="text-emerald-400">&quot;cust_123&quot;</span>,{"\n"}    units=<span className="text-amber-400">1500</span>,{"\n"}    properties={"{"}
              {"\n"}        <span className="text-emerald-400">&quot;model&quot;</span>: <span className="text-emerald-400">&quot;gpt-4o&quot;</span>,{"\n"}        <span className="text-emerald-400">&quot;input_tokens&quot;</span>: <span className="text-amber-400">1000</span>,{"\n"}    {"}"},{"\n"})</pre>
          </div>
        </CardBody>
      </Card>
    </div>
  );
}
SETTINGS

# ============================================
# POSTCSS
# ============================================
cat > postcss.config.js << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
EOF

echo ""
echo "========================================"
echo "  Frontend rebuilt. Run:"
echo "  cd web && pnpm dev"
echo "  Open http://localhost:3000/dashboard"
echo "========================================"