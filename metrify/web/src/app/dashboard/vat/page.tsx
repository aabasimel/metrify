"use client";

import { useVATTransactions } from "@/hooks/use-api";
import { formatCents, formatPercent } from "@/lib/utils";
import { MetricCard } from "@/components/ui/metric-card";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Table, THead, TH, TBody, TR, TD, TFoot } from "@/components/ui/table";

const treatmentLabel: Record<string, string> = { domestic: "Domestic", reverse_charge: "Reverse Charge", oss: "EU OSS", export: "Export" };
const treatmentVariant: Record<string, "default" | "info" | "warning" | "success"> = { domestic: "default", reverse_charge: "info", oss: "warning", export: "success" };

export default function VATPage() {
  const { data: vatTransactions, isLoading } = useVATTransactions();

  if (isLoading || !vatTransactions) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="animate-spin rounded-full h-6 w-6 border-2 border-brand-500 border-t-transparent" />
      </div>
    );
  }

  const totalVAT = vatTransactions.reduce((s: number, t: any) => s + t.vat, 0);
  const totalNet = vatTransactions.reduce((s: number, t: any) => s + t.net, 0);
  const domestic = vatTransactions.filter((t: any) => t.treatment === "domestic");
  const rc = vatTransactions.filter((t: any) => t.treatment === "reverse_charge");
  const oss = vatTransactions.filter((t: any) => t.treatment === "oss");
  const exp = vatTransactions.filter((t: any) => t.treatment === "export");

  const ossTotal = 685000;
  const ossThreshold = 1000000;
  const ossPct = (ossTotal / ossThreshold) * 100;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-xl font-bold tracking-tight">EU VAT Management</h1>
        <p className="text-xs text-zinc-500 mt-1">Tax compliance, OSS tracking, and calculations</p>
      </div>

      <div className="grid grid-cols-4 gap-4">
        <MetricCard label="VAT Collected" value={formatCents(totalVAT)} subValue={totalNet > 0 ? `${formatPercent(totalVAT / totalNet * 100)} effective rate` : ""} accent="amber" delay={0} />
        <MetricCard label="Domestic (DE)" value={formatCents(domestic.reduce((s: number, t: any) => s + t.vat, 0))} subValue={`${domestic.length} transactions · 19%`} delay={50} />
        <MetricCard label="EU OSS" value={formatCents(oss.reduce((s: number, t: any) => s + t.vat, 0))} subValue={`${oss.length} B2C transactions`} delay={100} />
        <MetricCard label="Reverse Charge" value={`${rc.length} invoices`} subValue="€0 VAT — buyer accounts" delay={150} />
      </div>

      <Card className={ossPct >= 80 ? "border-amber-500/20" : ""}>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle sub="€10,000 annual threshold for cross-border B2C">OSS Threshold</CardTitle>
            {ossPct >= 80 ? <Badge variant="warning">Approaching</Badge> : <Badge variant="success">Below</Badge>}
          </div>
        </CardHeader>
        <CardBody>
          <div className="space-y-4">
            <div>
              <div className="flex justify-between text-xs mb-2">
                <span className="text-zinc-500">Cross-border EU B2C (YTD)</span>
                <span className="font-mono text-zinc-300">{formatCents(ossTotal)} / {formatCents(ossThreshold)}</span>
              </div>
              <div className="h-2 bg-white/[0.04] rounded-full overflow-hidden">
                <div className={`h-full rounded-full transition-all duration-1000 ${ossPct >= 80 ? "bg-amber-500" : "bg-brand-500"}`} style={{ width: `${ossPct}%` }} />
              </div>
              <p className="text-2xs text-zinc-600 mt-1">{ossPct.toFixed(1)}% of threshold</p>
            </div>
            <p className="text-xs text-zinc-500">Monitor closely as you approach €10,000 in cross-border EU B2C sales.</p>
          </div>
        </CardBody>
      </Card>

      <div className="grid grid-cols-4 gap-4">
        {[
          { label: "Domestic", data: domestic, variant: "default" as const },
          { label: "Reverse Charge", data: rc, variant: "info" as const },
          { label: "EU OSS", data: oss, variant: "warning" as const },
          { label: "Export", data: exp, variant: "success" as const },
        ].map((g) => (
          <Card key={g.label} className="hover:border-white/[0.1] transition-colors">
            <CardBody>
              <Badge variant={g.variant} className="mb-3">{g.label}</Badge>
              <p className="text-xl font-bold">{formatCents(g.data.reduce((s: number, t: any) => s + t.net, 0))}</p>
              <p className="text-2xs text-zinc-500 mt-1">{g.data.length} transactions</p>
            </CardBody>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader><CardTitle sub="Per-customer VAT treatment">Transactions</CardTitle></CardHeader>
        <Table>
          <THead>
            <tr className="border-b border-white/[0.04]">
              <TH>Customer</TH><TH>Country</TH><TH>Treatment</TH><TH align="right">Rate</TH><TH align="right">Net</TH><TH align="right">VAT</TH><TH align="right">Gross</TH><TH>VAT Number</TH>
            </tr>
          </THead>
          <TBody>
            {vatTransactions.map((t: any, i: number) => (
              <TR key={i}>
                <TD className="font-medium text-zinc-300">{t.customer}</TD>
                <TD><span className="mr-1">{t.flag}</span><span className="text-zinc-500">{t.country}</span></TD>
                <TD><Badge variant={treatmentVariant[t.treatment] || "default"}>{treatmentLabel[t.treatment] || t.treatment}</Badge></TD>
                <TD align="right" mono className="text-zinc-400">{t.rate > 0 ? `${t.rate}%` : "—"}</TD>
                <TD align="right" mono className="text-zinc-300">{formatCents(t.net)}</TD>
                <TD align="right" mono>{t.vat > 0 ? <span className="text-amber-400">{formatCents(t.vat)}</span> : <span className="text-zinc-700">—</span>}</TD>
                <TD align="right" mono className="text-zinc-200">{formatCents(t.gross)}</TD>
                <TD className="text-2xs font-mono text-zinc-600">{t.vatNum || "—"}</TD>
              </TR>
            ))}
          </TBody>
          <TFoot>
            <tr>
              <TD colSpan={4} className="font-semibold text-zinc-300">Total</TD>
              <TD align="right" mono className="font-semibold">{formatCents(totalNet)}</TD>
              <TD align="right" mono className="text-amber-400 font-semibold">{formatCents(totalVAT)}</TD>
              <TD align="right" mono className="font-semibold">{formatCents(vatTransactions.reduce((s: number, t: any) => s + t.gross, 0))}</TD>
              <TD></TD>
            </tr>
          </TFoot>
        </Table>
      </Card>
    </div>
  );
}