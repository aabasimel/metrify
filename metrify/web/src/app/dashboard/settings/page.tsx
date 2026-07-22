"use client";

import { useState } from "react";
import { Card, CardHeader, CardBody, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

export default function SettingsPage() {
  const [copied, setCopied] = useState<string | null>(null);
  const copy = (key: string, val: string) => {
    navigator.clipboard.writeText(val);
    setCopied(key);
    setTimeout(() => setCopied(null), 2000);
  };

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-xl font-bold tracking-tight">Settings</h1>
        <p className="text-xs text-zinc-500 mt-1">Connections, API keys, and organization config</p>
      </div>

      {/* Connections */}
      <Card>
        <CardHeader>
          <CardTitle sub="Data sources for margin calculation">Connections</CardTitle>
        </CardHeader>
        <CardBody className="space-y-3">
          <div className="flex items-center justify-between bg-white/[0.03] rounded-xl px-4 py-3 border border-white/[0.04]">
            <div className="flex items-center gap-3">
              <div className="h-8 w-8 rounded-lg bg-[#635BFF]/10 flex items-center justify-center">
                <span className="text-[#635BFF] text-xs font-bold">S</span>
              </div>
              <div>
                <p className="text-xs font-medium text-zinc-300">Stripe</p>
                <p className="text-2xs text-zinc-600">Read-only · Revenue per customer</p>
              </div>
            </div>
            <Badge variant="success">Connected</Badge>
          </div>

          <div className="flex items-center justify-between bg-white/[0.03] rounded-xl px-4 py-3 border border-white/[0.04]">
            <div className="flex items-center gap-3">
              <div className="h-8 w-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                <span className="text-emerald-400 text-xs font-bold">O</span>
              </div>
              <div>
                <p className="text-xs font-medium text-zinc-300">OpenAI</p>
                <p className="text-2xs text-zinc-600">Cost data · sk-proj-...8f2a</p>
              </div>
            </div>
            <Badge variant="success">Connected</Badge>
          </div>

          <div className="flex items-center justify-between bg-white/[0.03] rounded-xl px-4 py-3 border border-white/[0.04]">
            <div className="flex items-center gap-3">
              <div className="h-8 w-8 rounded-lg bg-orange-500/10 flex items-center justify-center">
                <span className="text-orange-400 text-xs font-bold">A</span>
              </div>
              <div>
                <p className="text-xs font-medium text-zinc-300">Anthropic</p>
                <p className="text-2xs text-zinc-600">Cost data · sk-ant-...3d1b</p>
              </div>
            </div>
            <Badge variant="success">Connected</Badge>
          </div>
        </CardBody>
      </Card>

      {/* API Keys */}
      <Card>
        <CardHeader><CardTitle sub="For SDK integration">API Keys</CardTitle></CardHeader>
        <CardBody className="space-y-3">
          {[
            { label: "Live", key: "live", value: "mtfy_live_sk_a1b2c3d4e5f6g7h8i9j0" },
            { label: "Test", key: "test", value: "mtfy_test_sk_x9y8w7v6u5t4s3r2q1p0" },
          ].map((k) => (
            <div key={k.key} className="flex items-center justify-between bg-white/[0.03] rounded-xl px-4 py-3 border border-white/[0.04]">
              <div>
                <p className="text-2xs text-zinc-500 font-semibold uppercase tracking-wider">{k.label} Key</p>
                <code className="text-xs font-mono text-zinc-400 mt-0.5">{k.value.slice(0, 20)}...{k.value.slice(-4)}</code>
              </div>
              <Button variant="secondary" size="sm" onClick={() => copy(k.key, k.value)}>
                {copied === k.key ? "Copied ✓" : "Copy"}
              </Button>
            </div>
          ))}
        </CardBody>
      </Card>

      {/* Organization */}
      <Card>
        <CardHeader><CardTitle sub="Business details for VAT">Organization</CardTitle></CardHeader>
        <CardBody>
          <div className="grid grid-cols-4 gap-6 text-xs">
            <div><p className="text-zinc-600">Company</p><p className="text-zinc-300 mt-0.5">Demo GmbH</p></div>
            <div><p className="text-zinc-600">Country</p><p className="text-zinc-300 mt-0.5">🇩🇪 Germany</p></div>
            <div><p className="text-zinc-600">VAT Number</p><p className="font-mono text-zinc-300 mt-0.5">DE123456789</p></div>
            <div><p className="text-zinc-600">OSS</p><p className="text-emerald-400 mt-0.5">Registered</p></div>
          </div>
        </CardBody>
      </Card>

      {/* Quick Start */}
      <Card>
        <CardHeader><CardTitle sub="Start tracking margins in 2 minutes">Quick Start</CardTitle></CardHeader>
        <CardBody className="space-y-3">
          <div className="bg-surface-2 rounded-xl p-4 border border-white/[0.04] overflow-x-auto">
            <pre className="text-xs font-mono text-zinc-400 leading-relaxed">
              <span className="text-zinc-600"># Install the SDK</span>{"\n"}
              <span className="text-brand-400">pip install</span> metrify{"\n\n"}
              <span className="text-zinc-600"># Track AI calls</span>{"\n"}
              <span className="text-brand-400">from</span> metrify <span className="text-brand-400">import</span> Metrify{"\n"}
              m = Metrify(api_key=<span className="text-emerald-400">&quot;mtfy_live_sk_...&quot;</span>){"\n\n"}
              <span className="text-zinc-600"># After every AI call</span>{"\n"}
              m.track(<span className="text-emerald-400">&quot;ai_completion&quot;</span>,{"\n"}
              {"    "}customer_id=<span className="text-emerald-400">&quot;cust_123&quot;</span>,{"\n"}
              {"    "}properties={"{"}{"\n"}
              {"        "}<span className="text-emerald-400">&quot;model&quot;</span>: <span className="text-emerald-400">&quot;gpt-4o&quot;</span>,{"\n"}
              {"        "}<span className="text-emerald-400">&quot;input_tokens&quot;</span>: <span className="text-amber-400">1000</span>,{"\n"}
              {"        "}<span className="text-emerald-400">&quot;output_tokens&quot;</span>: <span className="text-amber-400">500</span>,{"\n"}
              {"    "}{"}"}{"\n"}
              )
            </pre>
          </div>
          <p className="text-2xs text-zinc-600">
            That&apos;s it. Metrify pulls revenue from Stripe, calculates costs from token usage, and shows you margins per customer.
          </p>
        </CardBody>
      </Card>
    </div>
  );
}