// Pure helpers shared by the pages. No Firebase imports, so they unit-test fast.

export type Totals = {
  input: number;
  output: number;
  cached: number;
  requests: number;
  errorRequests: number;
  chats: number;
  costMicro: number | null;
};

export type DailyRow = { uid: string; date: string; totals: Totals; byKey: Record<string, Totals> };

export type SyncRow = {
  uid: string;
  id: string;
  trigger: string;
  state: string;
  errorCode: string | null;
  createdAt: Date | null;
  startedAt: Date | null;
  finishedAt: Date | null;
};

export type CrashRow = {
  uid: string;
  id: string;
  type: string;
  message: string;
  platform: string;
  appVersion: string;
  screen: string;
  createdAt: Date | null;
  status: 'open' | 'resolved';
  adminNote: string;
  stack: string;
  resolvedAt: Date | null;
};

const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : 0);

export function toDate(v: unknown): Date | null {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v === 'object' && v !== null && 'toDate' in v && typeof (v as { toDate: unknown }).toDate === 'function')
    return (v as { toDate: () => Date }).toDate();
  if (typeof v === 'string') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

export function parseTotals(m: unknown): Totals {
  const o = (m ?? {}) as Record<string, unknown>;
  return {
    input: num(o.input),
    output: num(o.output),
    cached: num(o.cached),
    requests: num(o.requests),
    errorRequests: num(o.error_requests),
    chats: num(o.chats),
    costMicro: typeof o.cost_micro === 'number' ? o.cost_micro : null,
  };
}

export function emptyTotals(): Totals {
  return { input: 0, output: 0, cached: 0, requests: 0, errorRequests: 0, chats: 0, costMicro: 0 };
}

export function addTotals(a: Totals, b: Totals): Totals {
  return {
    input: a.input + b.input,
    output: a.output + b.output,
    cached: a.cached + b.cached,
    requests: a.requests + b.requests,
    errorRequests: a.errorRequests + b.errorRequests,
    chats: a.chats + b.chats,
    costMicro: (a.costMicro ?? 0) + (b.costMicro ?? 0),
  };
}

export const tokens = (t: Totals) => t.input + t.output;

/** YYYY-MM-DD for `days` ago in local time. */
export function dayKey(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

export function lastDays(n: number, now = new Date()): string[] {
  const out: string[] = [];
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    out.push(dayKey(d));
  }
  return out;
}

/** Sum of daily rows per date over the given day keys (missing days are zero). */
export function seriesByDay(rows: DailyRow[], days: string[]): { day: string; totals: Totals; users: number }[] {
  const map = new Map(days.map((d) => [d, { totals: emptyTotals(), users: new Set<string>() }]));
  for (const r of rows) {
    const slot = map.get(r.date);
    if (!slot) continue;
    slot.totals = addTotals(slot.totals, r.totals);
    if (tokens(r.totals) > 0) slot.users.add(r.uid);
  }
  return days.map((day) => ({ day, totals: map.get(day)!.totals, users: map.get(day)!.users.size }));
}

/** Totals per uid over the given day keys. */
export function totalsByUser(rows: DailyRow[], days: Set<string>): Map<string, Totals> {
  const out = new Map<string, Totals>();
  for (const r of rows) {
    if (!days.has(r.date)) continue;
    out.set(r.uid, addTotals(out.get(r.uid) ?? emptyTotals(), r.totals));
  }
  return out;
}

/** Totals grouped by a part of the by_key id (0 provider, 1 model). */
export function totalsByKeyPart(rows: DailyRow[], days: Set<string>, part: 0 | 1): [string, Totals][] {
  const out = new Map<string, Totals>();
  for (const r of rows) {
    if (!days.has(r.date)) continue;
    for (const [k, t] of Object.entries(r.byKey)) {
      const name = k.split('|')[part] ?? k;
      out.set(name, addTotals(out.get(name) ?? emptyTotals(), t));
    }
  }
  return [...out.entries()].sort((a, b) => tokens(b[1]) - tokens(a[1]));
}

/** Requests still pending/running longer than `minutes` are considered stuck. */
export function isStuck(s: SyncRow, now = new Date(), minutes = 10): boolean {
  if (s.state !== 'pending' && s.state !== 'running') return false;
  const since = s.startedAt ?? s.createdAt;
  return since !== null && now.getTime() - since.getTime() > minutes * 60_000;
}

export type SyncHealth = { total: number; done: number; failed: number; stuck: number; errors: [string, number][]; medianSeconds: number | null };

export function syncHealth(rows: SyncRow[], now = new Date()): SyncHealth {
  const errors = new Map<string, number>();
  const durations: number[] = [];
  let done = 0, failed = 0, stuck = 0;
  for (const s of rows) {
    if (s.state === 'done') done++;
    if (s.state === 'failed') {
      failed++;
      const code = s.errorCode ?? 'unknown';
      errors.set(code, (errors.get(code) ?? 0) + 1);
    }
    if (isStuck(s, now)) stuck++;
    if (s.state === 'done' && s.createdAt && s.finishedAt)
      durations.push((s.finishedAt.getTime() - s.createdAt.getTime()) / 1000);
  }
  durations.sort((a, b) => a - b);
  return {
    total: rows.length,
    done,
    failed,
    stuck,
    errors: [...errors.entries()].sort((a, b) => b[1] - a[1]),
    medianSeconds: durations.length ? durations[Math.floor(durations.length / 2)] : null,
  };
}

export function within(d: Date | null, days: number, now = new Date()): boolean {
  return d !== null && now.getTime() - d.getTime() <= days * 86_400_000;
}

// ── Formatting ──
export function fmtTokens(n: number): string {
  if (n >= 1e9) return `${(n / 1e9).toFixed(1)}B`;
  if (n >= 1e6) return `${(n / 1e6).toFixed(1)}M`;
  if (n >= 1e3) return `${(n / 1e3).toFixed(1)}K`;
  return String(n);
}

export function fmtUsd(micro: number | null): string {
  if (micro === null) return '—';
  return `$${(micro / 1e6).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export function fmtAgo(d: Date | null, now = new Date()): string {
  if (!d) return '—';
  const s = Math.round((now.getTime() - d.getTime()) / 1000);
  if (s < 60) return 'vừa xong';
  if (s < 3600) return `${Math.floor(s / 60)} phút trước`;
  if (s < 86400) return `${Math.floor(s / 3600)} giờ trước`;
  return `${Math.floor(s / 86400)} ngày trước`;
}

export function fmtDateTime(d: Date | null): string {
  return d ? d.toLocaleString('vi-VN', { dateStyle: 'short', timeStyle: 'short' }) : '—';
}

export function pct(part: number, total: number): string {
  return total === 0 ? '—' : `${Math.round((part / total) * 100)}%`;
}
