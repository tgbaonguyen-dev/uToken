import { Link } from 'react-router-dom';
import { loadCrashes, loadDailySince, loadSyncRequests, loadUsers } from '../lib/data';
import { dayKey, fmtAgo, fmtTokens, fmtUsd, lastDays, pct, seriesByDay, syncHealth, tokens, totalsByKeyPart, totalsByUser, within } from '../lib/stats';
import { Avatar, Bars, Card, HBars, Loading, Page, RefreshButton, Stat, providerName, useLoad } from '../ui';

export function Overview() {
  const days = lastDays(30);
  const state = useLoad(async () => {
    const [users, daily, syncs, crashes] = await Promise.all([loadUsers(), loadDailySince(days[0]), loadSyncRequests(), loadCrashes()]);
    return { users, daily, syncs, crashes };
  });

  return (
    <Page title="Tổng quan" sub="Toàn hệ thống · 30 ngày gần nhất" actions={<RefreshButton onClick={state.reload} loading={state.loading} />}>
      <Loading state={state}>
        {({ users, daily, syncs, crashes }) => {
          const now = new Date();
          const series = seriesByDay(daily, days);
          const total = series.reduce((s, d) => s + tokens(d.totals), 0);
          const cost = series.reduce((s, d) => s + (d.totals.costMicro ?? 0), 0);
          const active7 = users.filter((u) => within(u.lastSeenAt, 7, now) || within(u.lastSyncAt, 7, now)).length;
          const h = syncHealth(syncs.filter((s) => within(s.createdAt, 1, now)), now);
          const crash7 = crashes.filter((c) => within(c.createdAt, 7, now)).length;
          const open = crashes.filter((c) => c.status === 'open');
          const crashDays = lastDays(14);
          const crashSeries = crashDays.map((d) => crashes.filter((c) => c.createdAt !== null && dayKey(c.createdAt) === d).length);
          const daySet = new Set(days);
          const providers = totalsByKeyPart(daily, daySet, 0).map(([k, t]) => [providerName(k), tokens(t)] as [string, number]);
          const models = totalsByKeyPart(daily, daySet, 1).slice(0, 6).map(([k, t]) => [k, tokens(t)] as [string, number]);
          const perUser = totalsByUser(daily, daySet);
          const top = [...perUser.entries()].sort((a, b) => tokens(b[1]) - tokens(a[1])).slice(0, 6);
          const byUid = new Map(users.map((u) => [u.uid, u]));
          const errorRequests = series.reduce((s, d) => s + d.totals.errorRequests, 0);
          const requests = series.reduce((s, d) => s + d.totals.requests, 0);
          const alerts = [
            open.length > 0 && { tone: 'bad', text: `${open.length} crash chưa xử lý trên ${new Set(open.map((c) => c.uid)).size} người dùng`, to: '/crashes' },
            h.stuck > 0 && { tone: 'warn', text: `${h.stuck} yêu cầu sync bị kẹt quá 10 phút`, to: '/sync' },
            h.total > 0 && h.failed / h.total > 0.2 && { tone: 'warn', text: `Tỉ lệ sync lỗi 24 giờ qua cao (${pct(h.failed, h.total)})`, to: '/sync' },
          ].filter(Boolean) as { tone: string; text: string; to: string }[];
          return (
            <>
              {alerts.map((a) => (
                <Link key={a.text} to={a.to} className={`banner ${a.tone}`} style={{ color: 'var(--text)' }}>
                  <span className={`dot ${a.tone}`} style={{ marginTop: 5 }} /> <span style={{ flex: 1 }}>{a.text}</span> <span className="muted">Xem →</span>
                </Link>
              ))}
              <div className="grid kpis">
                <Stat icon="users" label="Người dùng" value={users.length} sub={`${active7} hoạt động trong 7 ngày`} />
                <Stat icon="coins" label="Token 30 ngày" value={fmtTokens(total)} sub={`${fmtUsd(cost)} chi phí ước tính`} />
                <Stat icon="sync" label="Sync 24 giờ" value={h.total} sub={`${pct(h.done, h.total)} thành công · ${h.stuck} kẹt`} tone={h.failed || h.stuck ? 'warn' : 'good'} />
                <Stat icon="bug" label="Crash 7 ngày" value={crash7} sub={`${open.length} chưa xử lý`} tone={open.length ? 'bad' : 'good'} />
                <Stat icon="alert" label="Request lỗi" value={pct(errorRequests, requests)} sub={`${errorRequests.toLocaleString()} / ${requests.toLocaleString()} request`} />
              </div>
              <div className="grid two">
                <Card title="Token mỗi ngày" hint="tất cả người dùng">
                  <div className="chart-total">{fmtTokens(total)}<span>30 ngày</span></div>
                  <Bars values={series.map((d) => tokens(d.totals))} labels={days} format={fmtTokens} />
                </Card>
                <Card title="Người dùng có usage" hint="mỗi ngày">
                  <div className="chart-total">{Math.max(0, ...series.map((d) => d.users))}<span>cao nhất / ngày</span></div>
                  <Bars color="blue" values={series.map((d) => d.users)} labels={days} format={(v) => `${v} người`} />
                </Card>
                <Card title="Crash mỗi ngày" hint="14 ngày" right={<Link to="/crashes" className="small">Xem tất cả →</Link>}>
                  <div className="chart-total">{crashSeries.reduce((a, b) => a + b, 0)}<span>báo cáo</span></div>
                  <Bars color="red" values={crashSeries} labels={crashDays} format={(v) => `${v} crash`} />
                </Card>
                <Card title="Công cụ và model" hint="theo token">
                  <HBars rows={providers} format={fmtTokens} />
                  <div style={{ height: 1, background: 'var(--line)', margin: '12px 0' }} />
                  <HBars rows={models} format={fmtTokens} />
                </Card>
              </div>
              <Card title="Người dùng nhiều token nhất" hint="30 ngày" right={<Link to="/users" className="small">Tất cả người dùng →</Link>}>
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>Người dùng</th><th className="num">Token</th><th className="num">Chi phí</th><th className="num">Chat</th><th>Sync gần nhất</th></tr></thead>
                    <tbody>
                      {top.map(([uid, t]) => {
                        const u = byUid.get(uid);
                        return (
                          <tr key={uid}>
                            <td><Link to={`/users/${uid}`} className="who" style={{ color: 'var(--text)' }}><Avatar name={u?.email ?? uid} />{u?.email ?? uid}</Link></td>
                            <td className="num">{fmtTokens(tokens(t))}</td>
                            <td className="num">{fmtUsd(t.costMicro)}</td>
                            <td className="num">{t.chats}</td>
                            <td className="muted">{fmtAgo(u?.lastSyncAt ?? null)}</td>
                          </tr>
                        );
                      })}
                      {top.length === 0 && <tr><td colSpan={5} className="empty">Chưa có usage.</td></tr>}
                    </tbody>
                  </table>
                </div>
              </Card>
            </>
          );
        }}
      </Loading>
    </Page>
  );
}
