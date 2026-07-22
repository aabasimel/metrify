"use client";

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from "recharts";
import { formatPercent, marginColor } from "@/lib/utils";

function ChartTooltip({ active, payload }: any) {
  if (!active || !payload?.[0]) return null;
  const d = payload[0].payload;
  const mc = marginColor(d.margin);
  return (
    <div className="rounded-xl border border-white/[0.08] bg-surface-2 px-4 py-3 shadow-2xl">
      <p className="text-xs font-semibold text-zinc-200 mb-2">{d.name}</p>
      <div className="space-y-1 text-2xs">
        <div className="flex justify-between gap-6"><span className="text-zinc-500">Revenue</span><span className="font-mono text-emerald-400">€{(d.revenue / 100).toFixed(0)}</span></div>
        <div className="flex justify-between gap-6"><span className="text-zinc-500">AI Cost</span><span className="font-mono text-red-400">€{(d.cost / 100).toFixed(0)}</span></div>
        <div className="flex justify-between gap-6 pt-1 border-t border-white/[0.06]"><span className="text-zinc-500">Margin</span><span className={`font-mono font-semibold ${mc.text}`}>{formatPercent(d.margin)}</span></div>
      </div>
    </div>
  );
}

export function MarginBarChart({ data }: { data: any[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data} margin={{ top: 5, right: 5, left: -20, bottom: 60 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" vertical={false} />
        <XAxis dataKey="name" tick={{ fill: "#3f3f46", fontSize: 10 }} tickLine={false} axisLine={false} angle={-45} textAnchor="end" interval={0} />
        <YAxis tick={{ fill: "#3f3f46", fontSize: 11 }} tickLine={false} axisLine={false} tickFormatter={(v) => `${v}%`} domain={[-60, 100]} />
        <Tooltip content={<ChartTooltip />} cursor={{ fill: "rgba(255,255,255,0.02)" }} />
        <Bar dataKey="margin" radius={[6, 6, 0, 0]} maxBarSize={32}>
          {data.map((d, i) => <Cell key={i} fill={marginColor(d.margin).dot} fillOpacity={0.8} />)}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
