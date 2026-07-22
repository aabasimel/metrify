"use client";

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";
import { formatCompact } from "@/lib/utils";

function ChartTooltip({ active, payload, label }: any) {
  if (!active || !payload) return null;
  return (
    <div className="rounded-xl border border-white/[0.08] bg-surface-2 px-4 py-3 shadow-2xl">
      <p className="text-2xs font-medium text-zinc-500 mb-2">{label}</p>
      {payload.map((p: any) => (
        <div key={p.name} className="flex items-center justify-between gap-6 py-0.5">
          <div className="flex items-center gap-2">
            <div className="h-2 w-2 rounded-full" style={{ background: p.color }} />
            <span className="text-xs text-zinc-400">{p.name}</span>
          </div>
          <span className="text-xs font-semibold font-mono text-zinc-200">{formatCompact(p.value)}</span>
        </div>
      ))}
    </div>
  );
}

interface LineConfig { key: string; name: string; color: string }

export function MetrifyLineChart({ data, lines, height = 320 }: { data: any[]; lines: LineConfig[]; height?: number }) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={data} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" vertical={false} />
        <XAxis dataKey="date" tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} />
        <YAxis tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} tickFormatter={formatCompact} />
        <Tooltip content={<ChartTooltip />} />
        {lines.map((l) => <Line key={l.key} type="monotone" dataKey={l.key} name={l.name} stroke={l.color} strokeWidth={1.5} dot={false} />)}
      </LineChart>
    </ResponsiveContainer>
  );
}
