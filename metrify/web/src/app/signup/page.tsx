"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/hooks/use-auth";

export default function SignupPage() {
  const [name, setName] = useState("");
  const [company, setCompany] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { signup, loginWithGoogle, loginAsDemo } = useAuth();
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    const result = await signup(email, password, name, company);
    if (result.success) {
      router.push("/dashboard");
    } else {
      setError(result.error || "Signup failed");
    }
    setLoading(false);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-surface-0">
      <div className="w-full max-w-sm px-6 py-12">
        <Link href="/" className="flex items-center justify-center gap-2 mb-10">
          <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center">
            <span className="text-white text-sm font-bold">M</span>
          </div>
          <span className="text-lg font-bold">metrify</span>
        </Link>

        <div className="text-center mb-8">
          <h1 className="text-xl font-bold">Create your account</h1>
          <p className="text-xs text-zinc-500 mt-1">Free plan · No credit card required</p>
        </div>

        {/* Google */}
        <button
          onClick={loginWithGoogle}
          className="w-full flex items-center justify-center gap-3 py-2.5 bg-white/[0.04] hover:bg-white/[0.08] border border-white/[0.08] rounded-xl text-sm font-medium text-zinc-300 transition-all active:scale-[0.98] mb-6"
        >
          <svg className="h-4 w-4" viewBox="0 0 24 24">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" />
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
          </svg>
          Sign up with Google
        </button>

        <div className="flex items-center gap-3 mb-6">
          <div className="flex-1 h-px bg-white/[0.06]" />
          <span className="text-2xs text-zinc-600">or</span>
          <div className="flex-1 h-px bg-white/[0.06]" />
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-2xs font-semibold uppercase tracking-wider text-zinc-500 block mb-1.5">Your name</label>
              <input
                type="text"
                value={name}
                onChange={(e) => { setName(e.target.value); setError(""); }}
                placeholder="Jane Smith"
                required
                className="w-full bg-white/[0.04] border border-white/[0.08] rounded-xl px-4 py-2.5 text-sm text-zinc-200 placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
              />
            </div>
            <div>
              <label className="text-2xs font-semibold uppercase tracking-wider text-zinc-500 block mb-1.5">Company</label>
              <input
                type="text"
                value={company}
                onChange={(e) => { setCompany(e.target.value); setError(""); }}
                placeholder="Acme GmbH"
                required
                className="w-full bg-white/[0.04] border border-white/[0.08] rounded-xl px-4 py-2.5 text-sm text-zinc-200 placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
              />
            </div>
          </div>

          <div>
            <label className="text-2xs font-semibold uppercase tracking-wider text-zinc-500 block mb-1.5">Work email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => { setEmail(e.target.value); setError(""); }}
              placeholder="jane@acme.com"
              required
              className="w-full bg-white/[0.04] border border-white/[0.08] rounded-xl px-4 py-2.5 text-sm text-zinc-200 placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
            />
          </div>

          <div>
            <label className="text-2xs font-semibold uppercase tracking-wider text-zinc-500 block mb-1.5">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => { setPassword(e.target.value); setError(""); }}
              placeholder="••••••••"
              required
              minLength={6}
              className="w-full bg-white/[0.04] border border-white/[0.08] rounded-xl px-4 py-2.5 text-sm text-zinc-200 placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all"
            />
            <p className="text-2xs text-zinc-600 mt-1">Minimum 6 characters</p>
          </div>

          {error && (
            <div className="bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5 text-xs text-red-400">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full py-2.5 bg-brand-600 hover:bg-brand-500 rounded-xl text-sm font-medium transition-all disabled:opacity-50 active:scale-[0.98]"
          >
            {loading ? "Creating account..." : "Create free account"}
          </button>
        </form>

        <div className="mt-6 pt-6 border-t border-white/[0.04] text-center">
          <button
            onClick={loginAsDemo}
            className="text-xs text-zinc-500 hover:text-zinc-300 transition-colors"
          >
            Just exploring? <span className="text-brand-400">Try the demo →</span>
          </button>
        </div>

        <p className="text-center text-xs text-zinc-600 mt-6">
          Already have an account?{" "}
          <Link href="/login" className="text-brand-400 hover:text-brand-300 transition-colors">
            Log in
          </Link>
        </p>

        <p className="text-center text-2xs text-zinc-700 mt-4">
          By signing up you agree to our Terms of Service and Privacy Policy
        </p>
      </div>
    </div>
  );
}