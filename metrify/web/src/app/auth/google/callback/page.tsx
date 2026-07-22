"use client";

import { useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";

function CallbackHandler() {
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    const code = searchParams.get("code");
    if (!code) {
      router.push("/login");
      return;
    }

    const API = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

    fetch(`${API}/v1/auth/google/callback`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code }),
    })
      .then((res) => {
        if (!res.ok) throw new Error("Auth failed");
        return res.json();
      })
      .then((userData) => {
        localStorage.setItem("metrify_user", JSON.stringify(userData));
        router.push("/dashboard");
      })
      .catch(() => {
        router.push("/login?error=google_auth_failed");
      });
  }, [router, searchParams]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-surface-0">
      <div className="text-center">
        <div className="animate-spin rounded-full h-8 w-8 border-2 border-brand-500 border-t-transparent mx-auto mb-4" />
        <p className="text-sm text-zinc-400">Signing you in...</p>
      </div>
    </div>
  );
}

export default function GoogleCallbackPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen flex items-center justify-center bg-surface-0">
        <div className="animate-spin rounded-full h-8 w-8 border-2 border-brand-500 border-t-transparent" />
      </div>
    }>
      <CallbackHandler />
    </Suspense>
  );
}