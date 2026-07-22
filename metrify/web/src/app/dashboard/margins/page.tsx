"use client";

import { useState } from "react";
import { useOverview } from "@/hooks/use-api";
import { formatCents, formatPercent, marginColor } from "@/lib/utils";
import { MetricCard } from "@/components/ui/metric-card";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { MarginBarChart } from "@/components/charts/bar-chart";
import { Table, THead, TH, TBody, TR, TD, TFoot } from "@/components/ui/table";

export default function MarginsPage() {
  const { data: margins, isLoading } = useOverview();
  const [sort, setSort] = useState<string>("revenue");

  if (isLoading || !margins) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="animate-spin rounded-full h-6 w-6 border-2 border-brand-500 border-t-transparent" />
      </div>
    );
  }

  const sorted = [...margins.customers].sort((a: any, b: any) => {
    if (sort === "margin_asc") return a.margin - b.margin;
    if (sort === "margin_desc") return b.margin - a.margin;
    if (sort === "cost") return b.cost - a.cost;
    return b.revenue - a.revenue;
  });

  const healthy = margins.customers.filter((c: any) => c.margin >= 50).length;
  const warning = margins.customers.filter((c: any) => c.margin >= 0 && c.margin < 50).length;
  const danger = margins.customers.filter((c: any) => c.margin < 0).length;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-xl font-bold tracking-tight">Margin Analysis</h1>
        <p className="text-xs text-zinc-500 mt-1">Per-customer profitability · {margins.period_start} to {margins.period_end}</p>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <MetricCard label="Overall Margin" value={formatPercent(margins.overall_margin_percent)} subValue={formatCents(margins.total_gross_profit_cents) + " profit"} accent="brand" delay={0} />
        <MetricCard label="Healthy (≥50%)" value={String(healthy)} subValue={`${((healthy / margins.customer_count) * 100).toFixed(0)}% of customers`} accent="green" delay={50} />
        <MetricCard label="Warning (0–50%)" value={String(warning)} subValue="Review pricing" accent="amber" delay={100} />
        <MetricCard label="Unprofitable (<0%)" value={String(danger)} subValue="Action needed" accent="red" delay={150} />
      </div>

      <Card>
        <CardHeader><CardTitle sub="Margin percentage by customer — red indicates loss">Margin Distribution</CardTitle></CardHeader>
        <CardBody className="pt-2"><MarginBarChart data={sorted} /></CardBody>
      </Card>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle sub={`${margins.customer_count} customers`}>Customer Detail</CardTitle>
            <select
              value={sort}
              onChange={(e) => setSort(e.target.value)}
              className="bg-white/[0.04] border border-white/[0.08] rounded-xl px-3 py-1.5 text-xs text-zinc-400 focus:outline-none focus:ring-1 focus:ring-brand-500/50"
            >
              <option value="revenue">Sort: Revenue</option>
              <option value="margin_desc">Sort: Margin ↓</option>
              <option value="margin_asc">Sort: Margin ↑</option>
              <option value="cost">Sort: AI Cost</option>
            </select>
          </div>
        </CardHeader>
        <Table>
          <THead>
            <tr className="border-b border-white/[0.04]">
              <TH>#</TH><TH>Customer</TH><TH align="right">Revenue</TH><TH align="right">AI Cost</TH><TH align="right">Profit</TH><TH align="right">Margin</TH><TH align="right">Status</TH>
            </tr>
          </THead>
          <TBody>
            {sorted.map((c: any, i: number) => {
              const mc = marginColor(c.margin);
              return (
                <TR key={c.id}>
                  <TD className="text-zinc-700 font-mono text-2xs">{i + 1}</TD>
                  <TD>
                    <div className="flex items-center gap-3">
                      <div className="h-7 w-7 rounded-lg bg-white/[0.04] flex items-center justify-center text-2xs font-bold text-zinc-500">{c.name.charAt(0)}</div>
                      <div>
                        <p className="text-[13px] font-medium text-zinc-200">{c.name}</p>
                        <p className="text-2xs text-zinc-600 font-mono">{c.ext}</p>
                      </div>
                    </div>
                  </TD>
                  <TD align="right" mono className="text-emerald-400">{formatCents(c.revenue)}</TD>
                  <TD align="right" mono className="text-red-400">{formatCents(c.cost)}</TD>
                  <TD align="right" mono className={c.profit >= 0 ? "text-emerald-400" : "text-red-400"}>{formatCents(c.profit)}</TD>
                  <TD align="right">
                    <span className={`text-2xs font-semibold font-mono px-2 py-0.5 rounded-lg ring-1 ring-inset ${mc.bg}`}>{formatPercent(c.margin)}</span>
                  </TD>
                  <TD align="right">
                    {c.margin >= 50 ? <Badge variant="success">Healthy</Badge> : c.margin >= 0 ? <Badge variant="warning">Warning</Badge> : <Badge variant="danger">Loss</Badge>}
                  </TD>
                </TR>
              );
            })}
          </TBody>
          <TFoot>
            <tr>
              <TD colSpan={2} className="font-semibold text-zinc-300">Total ({margins.customer_count})</TD>
              <TD align="right" mono className="text-emerald-400 font-semibold">{formatCents(margins.total_revenue_cents)}</TD>
              <TD align="right" mono className="text-red-400 font-semibold">{formatCents(margins.total_ai_cost_cents)}</TD>
              <TD align="right" mono className="text-emerald-400 font-semibold">{formatCents(margins.total_gross_profit_cents)}</TD>
              <TD align="right"><span className={`text-2xs font-semibold font-mono px-2 py-0.5 rounded-lg ring-1 ring-inset ${marginColor(margins.overall_margin_percent).bg}`}>{formatPercent(margins.overall_margin_percent)}</span></TD>
              <TD></TD>
            </tr>
          </TFoot>
        </Table>
      </Card>
    </div>
  );
}