"use client";

import { useUsageByEvent, useUsageTimeline } from "@/hooks/use-api";
import { formatCents, formatCompact } from "@/lib/utils";
import { MetricCard } from "@/components/ui/metric-card";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { MetrifyLineChart } from "@/components/charts/line-chart";
import { Table, THead, TH, TBody, TR, TD, TFoot } from "@/components/ui/table";

export default function UsagePage() {
  const { data: usageByEvent, isLoading: l1 } = useUsageByEvent();
  const { data: usageTimeline, isLoading: l2 } = useUsageTimeline();

  if (l1 || l2 || !usageByEvent || !usageTimeline) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="animate-spin rounded-full h-6 w-6 border-2 border-brand-500 border-t-transparent" />
      </div>
    );
  }

  const totalUnits = usageByEvent.reduce((s: number, e: any) => s + e.total, 0);
  const totalBillable = usageByEvent.reduce((s: number, e: any) => s + e.billable, 0);
  const totalRevenue = usageByEvent.reduce((s: number, e: any) => s + e.revenue, 0);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-xl font-bold tracking-tight">Usage Analytics</h1>
        <p className="text-xs text-zinc-500 mt-1">Event tracking and billable usage</p>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <MetricCard label="Total Events" value={formatCompact(totalUnits)} subValue={`${usageByEvent.length} event types`} delay={0} />
        <MetricCard label="Billable Units" value={formatCompact(totalBillable)} subValue={`${((totalBillable / totalUnits) * 100).toFixed(1)}% billable`} accent="brand" delay={50} />
        <MetricCard label="Usage Revenue" value={formatCents(totalRevenue)} subValue="From metered billing" accent="green" delay={100} />
        <MetricCard label="Avg / Customer" value={formatCents(Math.round(totalRevenue / 12))} subValue="12 active customers" delay={150} />
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle sub="Daily event volume by type">Usage Timeline</CardTitle>
            <div className="flex items-center gap-4 text-2xs">
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-brand-400" /><span className="text-zinc-500">Tokens</span></div>
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-violet-400" /><span className="text-zinc-500">API Calls</span></div>
              <div className="flex items-center gap-1.5"><div className="h-2 w-2 rounded-full bg-cyan-400" /><span className="text-zinc-500">Documents</span></div>
            </div>
          </div>
        </CardHeader>
        <CardBody className="pt-2">
          <MetrifyLineChart
            data={usageTimeline}
            lines={[
              { key: "tokens", name: "AI Tokens", color: "#818cf8" },
              { key: "calls", name: "API Calls", color: "#a78bfa" },
              { key: "docs", name: "Documents", color: "#22d3ee" },
            ]}
          />
        </CardBody>
      </Card>

      <Card>
        <CardHeader><CardTitle sub="All tracked events and billing impact">Events Breakdown</CardTitle></CardHeader>
        <Table>
          <THead>
            <tr className="border-b border-white/[0.04]">
              <TH>Event</TH><TH align="right">Total</TH><TH align="right">Billable</TH><TH align="right">Revenue</TH><TH align="right">Customers</TH><TH>Share</TH>
            </tr>
          </THead>
          <TBody>
            {usageByEvent.map((e: any) => {
              const share = totalRevenue > 0 ? (e.revenue / totalRevenue) * 100 : 0;
              return (
                <TR key={e.event}>
                  <TD><code className="text-xs font-mono text-brand-400 bg-brand-500/10 px-2 py-0.5 rounded-lg">{e.event}</code></TD>
                  <TD align="right" mono className="text-zinc-400">{formatCompact(e.total)}</TD>
                  <TD align="right" mono className="text-zinc-300">{formatCompact(e.billable)} <span className="text-zinc-600 text-2xs">({e.total > 0 ? ((e.billable / e.total) * 100).toFixed(0) : 0}%)</span></TD>
                  <TD align="right" mono className="text-emerald-400">{formatCents(e.revenue)}</TD>
                  <TD align="right" className="text-zinc-500">{e.customers}</TD>
                  <TD>
                    <div className="flex items-center gap-2">
                      <div className="flex-1 h-1.5 bg-white/[0.04] rounded-full overflow-hidden">
                        <div className="h-full bg-brand-500/60 rounded-full" style={{ width: `${share}%` }} />
                      </div>
                      <span className="text-2xs text-zinc-600 w-10 text-right font-mono">{share.toFixed(1)}%</span>
                    </div>
                  </TD>
                </TR>
              );
            })}
          </TBody>
          <TFoot>
            <tr>
              <TD className="font-semibold text-zinc-300">Total</TD>
              <TD align="right" mono className="font-semibold">{formatCompact(totalUnits)}</TD>
              <TD align="right" mono className="font-semibold">{formatCompact(totalBillable)}</TD>
              <TD align="right" mono className="text-emerald-400 font-semibold">{formatCents(totalRevenue)}</TD>
              <TD align="right" className="text-zinc-500">12</TD>
              <TD></TD>
            </tr>
          </TFoot>
        </Table>
      </Card>
    </div>
  );
}