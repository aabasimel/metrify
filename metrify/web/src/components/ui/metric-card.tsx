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
