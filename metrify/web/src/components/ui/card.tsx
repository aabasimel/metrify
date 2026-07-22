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
