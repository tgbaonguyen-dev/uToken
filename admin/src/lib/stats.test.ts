import { describe, expect, it } from 'vitest';
import { isStuck, lastDays, parseTotals, seriesByDay, syncHealth, totalsByKeyPart, totalsByUser, type SyncRow } from './stats';

const t = (input: number, cost = input * 10) => parseTotals({ input, output: 0, cached: 0, requests: 1, chats: 1, cost_micro: cost });

describe('stats', () => {
  it('lastDays ends today and has n entries', () => {
    const days = lastDays(3, new Date(2026, 10, 11));
    expect(days).toEqual(['2026-11-09', '2026-11-10', '2026-11-11']);
  });

  it('seriesByDay sums users per day and counts active users', () => {
    const days = ['2026-11-10', '2026-11-11'];
    const s = seriesByDay([
      { uid: 'a', date: '2026-11-10', totals: t(100), byKey: {} },
      { uid: 'b', date: '2026-11-10', totals: t(50), byKey: {} },
      { uid: 'a', date: '2026-01-01', totals: t(999), byKey: {} },
    ], days);
    expect(s[0].totals.input).toBe(150);
    expect(s[0].users).toBe(2);
    expect(s[1].totals.input).toBe(0);
  });

  it('totalsByUser and by key part', () => {
    const rows = [{ uid: 'a', date: 'd', totals: t(10), byKey: { 'codex|gpt-5|x': t(7), 'claude_code|sonnet|none': t(3) } }];
    expect(totalsByUser(rows, new Set(['d'])).get('a')?.input).toBe(10);
    expect(totalsByKeyPart(rows, new Set(['d']), 0).map((r) => r[0])).toEqual(['codex', 'claude_code']);
    expect(totalsByKeyPart(rows, new Set(['d']), 1)[0][0]).toBe('gpt-5');
  });

  it('sync health counts failures, stuck requests and median duration', () => {
    const now = new Date('2026-11-11T12:00:00Z');
    const at = (min: number) => new Date(now.getTime() - min * 60_000);
    const row = (state: string, created: number, finished?: number, errorCode: string | null = null): SyncRow =>
      ({ uid: 'u', id: Math.random().toString(), trigger: 'manual_refresh', state, errorCode, createdAt: at(created), startedAt: null, finishedAt: finished === undefined ? null : at(finished) });
    const rows = [row('done', 5, 4), row('done', 10, 9.5), row('failed', 3, 2, 'companion_offline'), row('pending', 30), row('running', 1)];
    const h = syncHealth(rows, now);
    expect(h).toMatchObject({ total: 5, done: 2, failed: 1, stuck: 1 });
    expect(h.errors).toEqual([['companion_offline', 1]]);
    expect(h.medianSeconds).toBe(60);
    expect(isStuck(rows[4], now)).toBe(false);
  });
});
