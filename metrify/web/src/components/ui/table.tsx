import { cn } from "@/lib/utils";
import { ReactNode, TdHTMLAttributes, ThHTMLAttributes } from "react";

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

interface TDProps extends TdHTMLAttributes<HTMLTableCellElement> {
  children?: ReactNode;
  align?: "left" | "right" | "center";
  mono?: boolean;
}

export function TD({ children, className, align = "left", mono, ...props }: TDProps) {
  return (
    <td
      className={cn(
        "px-5 py-4",
        align === "right" ? "text-right" : align === "center" ? "text-center" : "text-left",
        mono && "font-mono",
        className
      )}
      {...props}
    >
      {children}
    </td>
  );
}

export function TFoot({ children }: { children: ReactNode }) {
  return <tfoot className="border-t border-white/[0.08] bg-white/[0.02]">{children}</tfoot>;
}