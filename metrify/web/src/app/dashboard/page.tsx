"use client";

import { useOverview, useDailyRevenue, useCostsByModel } from "@/hooks/use-api";
import { formatCents, formatPercent, formatCompact, marginColor } from "@/lib/utils";
import { MetricCard } from "@/components/ui/metric-card";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { MetrifyAreaChart } from "@/components/charts/area-chart";
import { DonutChart } from "@/components/charts/donut-chart";

export default function OverviewPage() {
  const { data: margins, isLoading: l1 } = useOverview();
  const { data: dailyRevenue, isLoading: l2 } = useDailyRevenue();
  const { data: costsByModel, isLoading: l3 } = useCostsByModel();

  if (l1 || l2 || l3 || !margins || !dailyRevenue || !costsByModel) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="animate-spin rounded-full h-6 w-6 border-2 border-brand-500 border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-xl font-bold tracking-tight">Overview</h1>
        <p className="text-xs text-zinc-500 mt-1">{margins.period_start} to {margins.period_end} · {margins.customer_count} active customers</p>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <MetricCard label="Revenue" value={formatCents(margins.total_revenue_cents)} accent="green" delay={0} />
        <MetricCard label="AI Costs" value={formatCents(margins.total_ai_cost_cents)} subValue={`${formatPercent(margins.total_ai_cost_cents / margins.total_revenue_cents * 100)} of revenue`} accent="red" delay={50} />
        <MetricCard label="Gross Margin" value={formatPercent(margins.overall_margin_percent)} subValue={formatCents(margins.total_gross_profit_cents) + " profit"} accent="brand" delay={100} />
        <MetricCard label="Customers" value={String(margins.customer_count)} subValue={`${margins.unprofitable.length} unprofitable`} delay={150} />
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle sub="Daily revenue and AI cost trend">Revenue vs AI Cost</CardTitle>
            <div className="flex items-center gap-4 text-2xs">
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-emerald-400" /><span className="text-zinc-500">Revenue</span></div>
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-red-400" /><span className="text-zinc-500">AI Cost</span></div>
            </div>
          </div>
        </CardHeader>
        <CardBody className="pt-2">
          <MetrifyAreaChart
            data={dailyRevenue}
            areas={[
              { key: "revenue", name: "Revenue", color: "#34d399", gradient: "emerald" },
              { key: "cost", name: "AI Cost", color: "#f87171", gradient: "red" },
            ]}
          />
        </CardBody>
      </Card>

      <div className="grid grid-cols-5 gap-6">
        <Card className="col-span-2">
          <CardHeader><CardTitle sub="Spend by model this period">AI Cost Breakdown</CardTitle></CardHeader>
          <CardBody>
            <DonutChart data={costsByModel} centerLabel="total cost" centerValue={formatCents(margins.total_ai_cost_cents)} />
            <div className="mt-4 space-y-2">
              {costsByModel.map((m: any) => (
                <div key={m.model} className="flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2">
                    <div className="h-2.5 w-2.5 rounded" style={{ background: m.color }} />
                    <span className="text-zinc-400">{m.model}</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="font-mono text-zinc-500">{formatCents(m.cost)}</span>
                    <span className="text-2xs text-zinc-600 w-10 text-right">{m.pct}%</span>
                  </div>
                </div>
              ))}
            </div>
          </CardBody>
        </Card>

        <Card className="col-span-3">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle sub="Ranked by revenue">Top Customers</CardTitle>
              <Badge>{margins.customer_count} total</Badge>
            </div>
          </CardHeader>
          <div className="divide-y divide-white/[0.03]">
            {margins.customers.slice(0, 8).map((c: any, i: number) => {
              const mc = marginColor(c.margin);
              return (
                <div key={c.id} className="flex items-center justify-between px-6 py-3.5 hover:bg-white/[0.02] transition-colors">
                  <div className="flex items-center gap-3">
                    <span className="text-2xs text-zinc-700 font-mono w-4">{i + 1}</span>
                    <div className="h-7 w-7 rounded-lg bg-white/[0.04] flex items-center justify-center text-2xs font-bold text-zinc-500">
                      {c.name.charAt(0)}
                    </div>
                    <div>
                      <p className="text-[13px] font-medium text-zinc-300">{c.name}</p>
                      <p className="text-2xs text-zinc-600 font-mono">{formatCents(c.revenue)}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-2xs text-zinc-600 font-mono">cost {formatCents(c.cost)}</span>
                    <span className={`text-2xs font-semibold font-mono px-2 py-0.5 rounded-lg ring-1 ring-inset ${mc.bg}`}>
                      {formatPercent(c.margin)}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      </div>

      {margins.unprofitable.length > 0 && (
        <div className="rounded-2xl border border-red-500/20 bg-red-500/[0.04] p-5">
          <div className="flex items-center gap-2 mb-3">
            <div className="h-5 w-5 rounded-full bg-red-500/20 flex items-center justify-center">
              <span className="text-red-400 text-xs">!</span>
            </div>
            <p className="text-sm font-semibold text-red-400">{margins.unprofitable.length} customer losing money</p>
          </div>
          {margins.unprofitable.map((c: any) => (
            <div key={c.id} className="flex items-center justify-between bg-red-500/[0.04] rounded-xl px-4 py-3 mt-2">
              <div>
                <p className="text-sm font-medium text-zinc-300">{c.name}</p>
                <p className="text-2xs text-zinc-500 mt-0.5">Revenue {formatCents(c.revenue)} · Cost {formatCents(c.cost)} · Loss {formatCents(Math.abs(c.profit))}</p>
              </div>
              <Badge variant="danger">{formatPercent(c.margin)}</Badge>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}