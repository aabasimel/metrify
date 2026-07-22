const API = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

function getApiKey(): string {
  // Get API key from logged-in user session
  try {
    const saved = localStorage.getItem("metrify_user");
    if (saved) {
      const user = JSON.parse(saved);
      if (user.apiKey) return user.apiKey;
    }
  } catch {}
  // Fallback
  return process.env.NEXT_PUBLIC_API_KEY || "mtfy_live_sk_a1b2c3d4e5f6g7h8i9j0";
}

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${API}${path}`, {
    headers: { "X-Metrify-Key": getApiKey() },
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`API ${res.status}: ${await res.text()}`);
  return res.json();
}

// Use current month
const now = new Date();
const year = now.getFullYear();
const month = String(now.getMonth() + 1).padStart(2, "0");
const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
const start = `${year}-${month}-01`;
const end = `${year}-${month}-${String(lastDay).padStart(2, "0")}`;

export async function fetchOverview() {
  return get<any>(`/v1/dashboard/overview?period_start=${start}&period_end=${end}`);
}

export async function fetchDailyRevenue() {
  return get<any[]>(`/v1/dashboard/daily-revenue?period_start=${start}&period_end=${end}`);
}

export async function fetchCostsByModel() {
  return get<any[]>(`/v1/dashboard/costs-by-model?period_start=${start}&period_end=${end}`);
}

export async function fetchUsageByEvent() {
  return get<any[]>(`/v1/dashboard/usage-by-event?period_start=${start}&period_end=${end}`);
}

export async function fetchUsageTimeline() {
  return get<any[]>(`/v1/dashboard/usage-timeline?period_start=${start}&period_end=${end}`);
}

export async function fetchPendingSync() {
  return get<any[]>(`/v1/dashboard/pending-sync?period_start=${start}&period_end=${end}`);
}

export async function fetchVATTransactions() {
  return get<any[]>(`/v1/dashboard/vat-transactions?period_start=${start}&period_end=${end}`);
}

export const syncHistory = [
  { period: "January 2025", customers: 12, items: 18, amount: 4850000, date: "Feb 1, 2025" },
  { period: "December 2024", customers: 11, items: 16, amount: 4320000, date: "Jan 1, 2025" },
  { period: "November 2024", customers: 10, items: 15, amount: 3890000, date: "Dec 1, 2024" },
  { period: "October 2024", customers: 9, items: 14, amount: 3450000, date: "Nov 1, 2024" },
];