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
