// For now, simple credential-based auth
// In production, add Google/GitHub OAuth

export interface User {
  id: string;
  email: string;
  name: string;
  orgId: string;
  orgName: string;
  apiKey: string;
}

// Demo user — always available
export const DEMO_USER: User = {
  id: "demo",
  email: "demo@metrify.dev",
  name: "Demo User",
  orgId: "demo-org",
  orgName: "Demo GmbH",
  apiKey: "mtfy_live_sk_a1b2c3d4e5f6g7h8i9j0",
};

const API = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

export async function loginUser(email: string, password: string): Promise<User | null> {
  // Demo login — always works
  if (email === "demo@metrify.dev" && password === "demo") {
    return DEMO_USER;
  }

  // Real login — call your backend
  try {
    const res = await fetch(`${API}/v1/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    if (!res.ok) return null;
    return res.json();
  } catch {
    return null;
  }
}

export async function signupUser(
  email: string,
  password: string,
  name: string,
  companyName: string,
): Promise<User | null> {
  try {
    const res = await fetch(`${API}/v1/auth/signup`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, name, company_name: companyName }),
    });
    if (!res.ok) return null;
    return res.json();
  } catch {
    return null;
  }
}