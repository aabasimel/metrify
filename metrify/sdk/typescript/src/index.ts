interface MetrifyConfig {
  apiKey: string;
  baseUrl?: string;
  flushInterval?: number;
  flushSize?: number;
}

interface TrackOptions {
  customerId: string;
  units?: number;
  properties?: Record<string, unknown>;
  timestamp?: Date;
  idempotencyKey?: string;
}

interface EventPayload {
  event_name: string;
  customer_id: string;
  units: number;
  properties?: Record<string, unknown>;
  timestamp: string;
  idempotency_key: string;
}

export class Metrify {
  private apiKey: string;
  private baseUrl: string;
  private flushInterval: number;
  private flushSize: number;
  private buffer: EventPayload[] = [];
  private timer: ReturnType<typeof setInterval> | null = null;

  constructor(config: MetrifyConfig) {
    this.apiKey = config.apiKey;
    this.baseUrl = (config.baseUrl || "https://api.metrify.dev").replace(/\/$/, "");
    this.flushInterval = config.flushInterval || 5000;
    this.flushSize = config.flushSize || 100;
    this.timer = setInterval(() => this.flush(), this.flushInterval);
    if (typeof process !== "undefined" && process.on) {
      process.on("beforeExit", () => this.flush());
    }
  }

  track(eventName: string, options: TrackOptions): void {
    this.buffer.push({
      event_name: eventName,
      customer_id: options.customerId,
      units: options.units ?? 1,
      properties: options.properties,
      timestamp: (options.timestamp || new Date()).toISOString(),
      idempotency_key: options.idempotencyKey || crypto.randomUUID(),
    });
    if (this.buffer.length >= this.flushSize) this.flush();
  }

  async flush(): Promise<void> {
    if (this.buffer.length === 0) return;
    const events = [...this.buffer];
    this.buffer = [];
    try {
      const res = await fetch(`${this.baseUrl}/v1/events/batch`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Metrify-Key": this.apiKey },
        body: JSON.stringify({ events }),
      });
      if (!res.ok) this.buffer = [...events, ...this.buffer];
    } catch {
      this.buffer = [...events, ...this.buffer];
    }
  }

  shutdown(): void {
    if (this.timer) { clearInterval(this.timer); this.timer = null; }
    this.flush();
  }
}

export default Metrify;
