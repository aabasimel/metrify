import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen bg-surface-0 text-white">
      {/* Nav */}
      <nav className="flex items-center justify-between px-8 py-5 max-w-6xl mx-auto">
        <div className="flex items-center gap-2">
          <div className="h-7 w-7 rounded-lg bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center">
            <span className="text-white text-xs font-bold">M</span>
          </div>
          <span className="text-sm font-bold">metrify</span>
        </div>
        <div className="flex items-center gap-6">
          <a href="#how" className="text-xs text-zinc-500 hover:text-zinc-300 transition-colors">How it works</a>
          <a href="#pricing" className="text-xs text-zinc-500 hover:text-zinc-300 transition-colors">Pricing</a>
          <Link href="/login" className="text-xs text-zinc-500 hover:text-zinc-300 transition-colors">Log in</Link>
<Link
  href="/signup"
  className="px-4 py-1.5 bg-brand-600 hover:bg-brand-500 rounded-lg text-xs font-medium transition-colors"
>
  Start free →
</Link>
        </div>
      </nav>

      {/* Hero */}
      <section className="max-w-4xl mx-auto px-8 pt-24 pb-20 text-center">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-brand-500/10 border border-brand-500/20 mb-8">
          <div className="h-1.5 w-1.5 rounded-full bg-brand-400 animate-pulse" />
          <span className="text-2xs font-medium text-brand-400">For AI-native companies using Stripe</span>
        </div>

        <h1 className="text-5xl font-bold tracking-tight leading-[1.1]">
          You know your MRR.<br />
          You know your AI bill.<br />
          <span className="text-gradient from-brand-400 to-purple-400">But which customers are profitable?</span>
        </h1>

        <p className="text-lg text-zinc-400 mt-6 max-w-2xl mx-auto leading-relaxed">
          Metrify connects your Stripe revenue to your OpenAI and Anthropic costs.
          See your real margins — per customer, per model, per day.
          Set up in 10 minutes.
        </p>

        <div className="flex items-center justify-center gap-4 mt-10">
          <Link
            href="/dashboard"
            className="px-8 py-3 bg-brand-600 hover:bg-brand-500 rounded-xl font-medium text-sm transition-all shadow-lg shadow-brand-600/20 active:scale-[0.98]"
          >
            See the demo →
          </Link>
          <a
            href="#how"
            className="px-8 py-3 bg-white/[0.04] hover:bg-white/[0.08] rounded-xl font-medium text-sm text-zinc-400 transition-all ring-1 ring-inset ring-white/[0.06]"
          >
            How it works
          </a>
        </div>

        {/* Social proof */}
        <p className="text-2xs text-zinc-600 mt-8">
          Used by AI startups processing millions of tokens per day
        </p>
      </section>

      {/* Problem */}
      <section className="max-w-5xl mx-auto px-8 py-20">
        <div className="grid grid-cols-2 gap-16 items-center">
          <div>
            <p className="text-2xs font-semibold uppercase tracking-[0.2em] text-red-400 mb-4">The problem</p>
            <h2 className="text-2xl font-bold tracking-tight">
              Your fastest-growing customers might be your most expensive
            </h2>
            <p className="text-sm text-zinc-400 mt-4 leading-relaxed">
              Flat-rate pricing + variable AI costs = invisible losses.
              A customer paying €49/month could be costing you €200 in API calls.
              You won&apos;t know until it&apos;s too late.
            </p>
          </div>
          <div className="bg-white/[0.02] border border-white/[0.06] rounded-2xl p-6 font-mono text-xs">
            <p className="text-zinc-500 mb-3">Your Stripe dashboard says:</p>
            <p className="text-emerald-400">  MRR: €9,800 ✓</p>
            <p className="text-emerald-400">  Customers: 200 ✓</p>
            <p className="text-emerald-400 mb-4">  Churn: 3.2% ✓</p>
            <p className="text-zinc-500 mb-3">Your OpenAI dashboard says:</p>
            <p className="text-red-400">  Monthly cost: €4,200</p>
            <p className="text-zinc-600 mb-4">  (but which customers caused this?)</p>
            <p className="text-zinc-500 mb-3">What you don&apos;t know:</p>
            <p className="text-red-400">  12 customers cost more than they pay</p>
            <p className="text-red-400">  Customer #47 alone loses you €131/month</p>
            <p className="text-red-400">  Your real margin is 38%, not 57%</p>
          </div>
        </div>
      </section>

      {/* Solution */}
      <section id="how" className="max-w-5xl mx-auto px-8 py-20">
        <div className="text-center mb-16">
          <p className="text-2xs font-semibold uppercase tracking-[0.2em] text-brand-400 mb-4">How it works</p>
          <h2 className="text-2xl font-bold tracking-tight">Three connections. Full visibility.</h2>
        </div>

        <div className="grid grid-cols-3 gap-6">
          <div className="bg-white/[0.02] border border-white/[0.06] rounded-2xl p-6 hover:border-white/[0.1] transition-colors">
            <div className="h-10 w-10 rounded-xl bg-emerald-500/10 flex items-center justify-center mb-4">
              <span className="text-emerald-400 text-lg">1</span>
            </div>
            <h3 className="text-sm font-semibold mb-2">Connect Stripe</h3>
            <p className="text-xs text-zinc-500 leading-relaxed">
              Read-only access. We pull your revenue per customer.
              We never touch your billing or charge anyone.
            </p>
            <div className="mt-4 bg-surface-2 rounded-lg p-3">
              <code className="text-2xs text-zinc-400">
                Revenue per customer ← Stripe
              </code>
            </div>
          </div>

          <div className="bg-white/[0.02] border border-white/[0.06] rounded-2xl p-6 hover:border-white/[0.1] transition-colors">
            <div className="h-10 w-10 rounded-xl bg-brand-500/10 flex items-center justify-center mb-4">
              <span className="text-brand-400 text-lg">2</span>
            </div>
            <h3 className="text-sm font-semibold mb-2">Add the SDK</h3>
            <p className="text-xs text-zinc-500 leading-relaxed">
              One line of code after each AI call. We track which customer
              used which model and how many tokens.
            </p>
            <div className="mt-4 bg-surface-2 rounded-lg p-3">
              <pre className="text-2xs text-zinc-400">
{`m.track("ai_completion",
  customer_id="cust_123",
  properties={
    "model": "gpt-4o",
    "tokens": 1500
  })`}
              </pre>
            </div>
          </div>

          <div className="bg-white/[0.02] border border-white/[0.06] rounded-2xl p-6 hover:border-white/[0.1] transition-colors">
            <div className="h-10 w-10 rounded-xl bg-purple-500/10 flex items-center justify-center mb-4">
              <span className="text-purple-400 text-lg">3</span>
            </div>
            <h3 className="text-sm font-semibold mb-2">See your margins</h3>
            <p className="text-xs text-zinc-500 leading-relaxed">
              Instantly see which customers are profitable, which models
              cost the most, and where you&apos;re losing money.
            </p>
            <div className="mt-4 bg-surface-2 rounded-lg p-3">
              <code className="text-2xs text-zinc-400">
                Revenue - AI Cost = Real Margin
              </code>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="max-w-5xl mx-auto px-8 py-20">
        <div className="text-center mb-16">
          <p className="text-2xs font-semibold uppercase tracking-[0.2em] text-brand-400 mb-4">What you get</p>
          <h2 className="text-2xl font-bold tracking-tight">The data your spreadsheet can&apos;t give you</h2>
        </div>

        <div className="grid grid-cols-2 gap-6">
          {[
            {
              title: "Per-customer margins",
              desc: "See revenue, AI cost, and profit for every customer. Spot unprofitable accounts instantly.",
              color: "emerald",
            },
            {
              title: "Cost by model",
              desc: "Know exactly how much you spend on gpt-4o vs gpt-4o-mini vs Claude. Find optimization opportunities.",
              color: "brand",
            },
            {
              title: "Margin alerts",
              desc: "Get notified when a customer becomes unprofitable or when your overall margin drops below a threshold.",
              color: "amber",
            },
            {
              title: "EU VAT intelligence",
              desc: "Automatic VAT calculation for 27 EU countries. Reverse charge, OSS threshold tracking, compliance dashboard.",
              color: "purple",
            },
            {
              title: "Model optimization insights",
              desc: "We analyze usage patterns and suggest where you can switch to cheaper models without quality loss.",
              color: "cyan",
            },
            {
              title: "Margin trends",
              desc: "Track how your margins change over time. See if pricing changes are working. Forecast profitability.",
              color: "pink",
            },
          ].map((feature) => (
            <div
              key={feature.title}
              className="bg-white/[0.02] border border-white/[0.06] rounded-2xl p-6 hover:border-white/[0.1] transition-colors"
            >
              <h3 className="text-sm font-semibold mb-2">{feature.title}</h3>
              <p className="text-xs text-zinc-500 leading-relaxed">{feature.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="max-w-5xl mx-auto px-8 py-20">
        <div className="text-center mb-16">
          <p className="text-2xs font-semibold uppercase tracking-[0.2em] text-brand-400 mb-4">Pricing</p>
          <h2 className="text-2xl font-bold tracking-tight">Starts free. Pays for itself day one.</h2>
        </div>

        <div className="grid grid-cols-3 gap-6">
          {[
            {
              name: "Free",
              price: "€0",
              desc: "Try it out",
              features: ["5 customers", "10K events/month", "7-day data retention", "Margin dashboard"],
              cta: "Start free",
              highlight: false,
            },
            {
              name: "Growth",
              price: "€49",
              desc: "per month",
              features: ["50 customers", "500K events/month", "90-day retention", "EU VAT engine", "Margin alerts", "Email support"],
              cta: "Start trial",
              highlight: true,
            },
            {
              name: "Scale",
              price: "€149",
              desc: "per month",
              features: ["Unlimited customers", "Unlimited events", "Unlimited retention", "Model optimization insights", "Slack alerts", "Priority support"],
              cta: "Start trial",
              highlight: false,
            },
          ].map((plan) => (
            <div
              key={plan.name}
              className={`rounded-2xl p-6 border ${
                plan.highlight
                  ? "bg-brand-500/[0.05] border-brand-500/30 ring-1 ring-brand-500/20"
                  : "bg-white/[0.02] border-white/[0.06]"
              }`}
            >
              <p className="text-sm font-semibold">{plan.name}</p>
              <div className="mt-2 mb-4">
                <span className="text-3xl font-bold">{plan.price}</span>
                <span className="text-xs text-zinc-500 ml-1">{plan.desc}</span>
              </div>
              <ul className="space-y-2 mb-6">
                {plan.features.map((f) => (
                  <li key={f} className="flex items-center gap-2 text-xs text-zinc-400">
                    <span className="text-emerald-400">✓</span>
                    {f}
                  </li>
                ))}
              </ul>
              <button
                className={`w-full py-2 rounded-xl text-sm font-medium transition-all ${
                  plan.highlight
                    ? "bg-brand-600 hover:bg-brand-500 text-white"
                    : "bg-white/[0.06] hover:bg-white/[0.1] text-zinc-300"
                }`}
              >
                {plan.cta}
              </button>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="max-w-3xl mx-auto px-8 py-20 text-center">
        <h2 className="text-2xl font-bold tracking-tight">
          Stop guessing. Start knowing.
        </h2>
        <p className="text-sm text-zinc-400 mt-3">
          Set up in 10 minutes. See your first margin report today.
        </p>
        <Link
  href="/signup"
  className="px-8 py-3 bg-brand-600 hover:bg-brand-500 rounded-xl font-medium text-sm transition-all shadow-lg shadow-brand-600/20 active:scale-[0.98]"
>
  Start free →
</Link>
  <Link
    href="/login"
    className="px-8 py-3 bg-white/[0.04] hover:bg-white/[0.08] rounded-xl font-medium text-sm text-zinc-400 transition-all ring-1 ring-inset ring-white/[0.06]"
  >
    Log in
  </Link>
      </section>

      {/* Footer */}
      <footer className="border-t border-white/[0.04] py-8 px-8">
        <div className="max-w-5xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="h-5 w-5 rounded bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center">
              <span className="text-white text-2xs font-bold">M</span>
            </div>
            <span className="text-xs text-zinc-500">metrify</span>
          </div>
          <p className="text-2xs text-zinc-600">Margin intelligence for AI companies</p>
        </div>
      </footer>
    </div>
  );
}