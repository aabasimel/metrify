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
