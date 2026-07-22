"use client";

import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from "recharts";
import { formatCents } from "@/lib/utils";

function ChartTooltip({ active, payload }: any) {
  if (!active || !payload?.[0]) return null;
  const d = payload[0].payload;
  return (
    <div className="rounded-xl border border-white/[0.08] bg-surface-2 px-4 py-3 shadow-2xl">
      <p className="text-xs font-semibold text-zinc-200">{d.model}</p>
      <p className="text-2xs text-zinc-500">{d.provider}</p>
      <p className="text-xs font-mono text-zinc-300 mt-1">{formatCents(d.cost)} · {d.pct}%</p>
    </div>
  );
}

export function DonutChart({ data, centerLabel, centerValue }: { data: any[]; centerLabel: string; centerValue: string }) {
  return (
    <div className="relative">
      <ResponsiveContainer width="100%" height={220}>
        <PieChart>
          <Pie data={data} cx="50%" cy="50%" innerRadius={65} outerRadius={90} dataKey="cost" stroke="none" paddingAngle={2}>
            {data.map((d, i) => <Cell key={i} fill={d.color} />)}
          </Pie>
          <Tooltip content={<ChartTooltip />} />
        </PieChart>
      </ResponsiveContainer>
      <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
        <p className="text-lg font-bold">{centerValue}</p>
        <p className="text-2xs text-zinc-500">{centerLabel}</p>
      </div>
    </div>
  );
}
