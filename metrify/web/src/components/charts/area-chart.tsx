"use client";

import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";
import { formatCents } from "@/lib/utils";

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
          <span className="text-xs font-semibold font-mono text-zinc-200">{formatCents(p.value)}</span>
        </div>
      ))}
    </div>
  );
}

interface Props {
  data: any[];
  areas: { key: string; name: string; color: string; gradient: string }[];
  height?: number;
}

export function MetrifyAreaChart({ data, areas, height = 320 }: Props) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
        <defs>
          {areas.map((a) => (
            <linearGradient key={a.key} id={`grad-${a.key}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={a.color} stopOpacity={0.15} />
              <stop offset="100%" stopColor={a.color} stopOpacity={0} />
            </linearGradient>
          ))}
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" vertical={false} />
        <XAxis dataKey="date" tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} />
        <YAxis tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} tickFormatter={(v) => `€${(v / 100).toFixed(0)}`} />
        <Tooltip content={<ChartTooltip />} />
        {areas.map((a) => (
          <Area key={a.key} type="monotone" dataKey={a.key} name={a.name} stroke={a.color} fill={`url(#grad-${a.key})`} strokeWidth={1.5} dot={false} />
        ))}
      </AreaChart>
    </ResponsiveContainer>
  );
}
