"use client";

import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from "react";
import { useRouter } from "next/navigation";

interface User {
  id: string;
  email: string;
  name: string;
  orgId: string;
  orgName: string;
  apiKey: string;
  avatar?: string;
}

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<{ success: boolean; error?: string }>;
  signup: (email: string, password: string, name: string, company: string) => Promise<{ success: boolean; error?: string }>;
  loginWithGoogle: () => void;
  loginAsDemo: () => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | null>(null);
const API = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
const GOOGLE_CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID || "";

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  // Load saved session
  useEffect(() => {
    try {
      const saved = localStorage.getItem("metrify_user");
      if (saved) setUser(JSON.parse(saved));
    } catch {}
    setLoading(false);
  }, []);

  const saveUser = (userData: User) => {
    setUser(userData);
    localStorage.setItem("metrify_user", JSON.stringify(userData));
  };

  const login = async (email: string, password: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch(`${API}/v1/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();

      if (!res.ok) {
        return { success: false, error: data.detail || "Login failed" };
      }

      saveUser(data);
      return { success: true };
    } catch {
      return { success: false, error: "Cannot connect to server" };
    }
  };

  const signup = async (email: string, password: string, name: string, company: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch(`${API}/v1/auth/signup`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, name, company_name: company }),
      });

      const data = await res.json();

      if (!res.ok) {
        return { success: false, error: data.detail || "Signup failed" };
      }

      saveUser(data);
      return { success: true };
    } catch {
      return { success: false, error: "Cannot connect to server" };
    }
  };

  const loginWithGoogle = useCallback(() => {
    if (!GOOGLE_CLIENT_ID) {
      // Dev mode: simulate Google login
      const mockLogin = async () => {
        try {
          const res = await fetch(`${API}/v1/auth/google`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              email: "googleuser@gmail.com",
              name: "Google User",
            }),
          });

          if (res.ok) {
            const data = await res.json();
            saveUser(data);
            router.push("/dashboard");
          }
        } catch (err) {
          console.error("Google auth failed:", err);
        }
      };
      mockLogin();
      return;
    }

    // Real Google OAuth redirect
    const params = new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      redirect_uri: `${window.location.origin}/auth/google/callback`,
      response_type: "code",
      scope: "openid email profile",
      access_type: "offline",
      prompt: "consent",
    });

    window.location.href = `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
  }, [router]);

  const loginAsDemo = useCallback(async () => {
    const result = await login("demo@metrify.dev", "demo");
    if (result.success) {
      router.push("/dashboard");
    }
  }, [router]);

  const logout = useCallback(() => {
    setUser(null);
    localStorage.removeItem("metrify_user");
    router.push("/");
  }, [router]);

  return (
    <AuthContext.Provider value={{ user, loading, login, signup, loginWithGoogle, loginAsDemo, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used within AuthProvider");
  return context;
}