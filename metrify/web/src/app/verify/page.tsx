"use client";

import { useState, useRef, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/hooks/use-auth";

const API = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

export default function VerifyPage() {
  const [code, setCode] = useState(["", "", "", "", "", ""]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [resent, setResent] = useState(false);
  const inputs = useRef<(HTMLInputElement | null)[]>([]);
  const { user } = useAuth();
  const router = useRouter();

  const email = user?.email || "";

  useEffect(() => {
    if (!email) router.push("/signup");
    inputs.current[0]?.focus();
  }, [email, router]);

  const handleChange = (index: number, value: string) => {
    if (value.length > 1) value = value[value.length - 1];
    if (!/^\d*$/.test(value)) return;

    const newCode = [...code];
    newCode[index] = value;
    setCode(newCode);
    setError("");

    if (value && index < 5) {
      inputs.current[index + 1]?.focus();
    }

    // Auto-submit when all 6 digits entered
    if (newCode.every((d) => d !== "")) {
      handleSubmit(newCode.join(""));
    }
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === "Backspace" && !code[index] && index > 0) {
      inputs.current[index - 1]?.focus();
    }
  };

  const handlePaste = (e: React.ClipboardEvent) => {
    e.preventDefault();
    const pasted = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
    const newCode = [...code];
    for (let i = 0; i < pasted.length; i++) {
      newCode[i] = pasted[i];
    }
    setCode(newCode);
    if (pasted.length === 6) {
      handleSubmit(pasted);
    }
  };

  const handleSubmit = async (fullCode: string) => {
    setError("");
    setLoading(true);

    try {
      const res = await fetch(`${API}/v1/auth/verify-email`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, code: fullCode }),
      });

      const data = await res.json();

      if (!res.ok) {
        setError(data.detail || "Invalid code");
        setCode(["", "", "", "", "", ""]);
        inputs.current[0]?.focus();
        setLoading(false);
        return;
      }

      // Update stored user with verified status
      localStorage.setItem("metrify_user", JSON.stringify(data));
      router.push("/dashboard");
    } catch {
      setError("Cannot connect to server");
    }
    setLoading(false);
  };

  const handleResend = async () => {
    try {
      await fetch(`${API}/v1/auth/resend-code`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      setResent(true);
      setTimeout(() => setResent(false), 5000);
    } catch {}
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-surface-0">
      <div className="w-full max-w-sm px-6 text-center">
        <Link href="/" className="flex items-center justify-center gap-2 mb-10">
          <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center">
            <span className="text-white text-sm font-bold">M</span>
          </div>
          <span className="text-lg font-bold">metrify</span>
        </Link>

        <div className="mb-8">
          <h1 className="text-xl font-bold">Check your email</h1>
          <p className="text-xs text-zinc-500 mt-2">
            We sent a 6-digit code to
          </p>
          <p className="text-sm font-medium text-zinc-300 mt-1">{email}</p>
        </div>

        {/* Code input */}
        <div className="flex justify-center gap-2 mb-6" onPaste={handlePaste}>
          {code.map((digit, i) => (
            <input
              key={i}
              ref={(el) => { inputs.current[i] = el; }}
              type="text"
              inputMode="numeric"
              maxLength={1}
              value={digit}
              onChange={(e) => handleChange(i, e.target.value)}
              onKeyDown={(e) => handleKeyDown(i, e)}
              className="w-12 h-14 text-center text-xl font-bold font-mono bg-white/[0.04] border border-white/[0.08] rounded-xl text-zinc-200 focus:outline-none focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500/50 transition-all"
            />
          ))}
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5 text-xs text-red-400 mb-4">
            {error}
          </div>
        )}

        {loading && (
          <div className="flex items-center justify-center gap-2 mb-4">
            <div className="animate-spin rounded-full h-4 w-4 border-2 border-brand-500 border-t-transparent" />
            <span className="text-xs text-zinc-400">Verifying...</span>
          </div>
        )}

        <p className="text-xs text-zinc-600 mt-6">
          Didn&apos;t receive the code?{" "}
          <button
            onClick={handleResend}
            className="text-brand-400 hover:text-brand-300 transition-colors"
          >
            {resent ? "Code sent ✓" : "Resend code"}
          </button>
        </p>

        <p className="text-2xs text-zinc-700 mt-4">
          Code expires in 10 minutes
        </p>

        {/* Dev helper */}
        <div className="mt-8 pt-6 border-t border-white/[0.04]">
          <p className="text-2xs text-zinc-700">
            Development mode: check your terminal for the verification code
          </p>
        </div>
      </div>
    </div>
  );
}