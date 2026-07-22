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
