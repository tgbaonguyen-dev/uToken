import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { loadCrashes, loadDailySince, loadUsers, type UserRow } from '../lib/data';
import { emptyTotals, fmtAgo, fmtTokens, fmtUsd, lastDays, tokens, totalsByUser, within, type CrashRow, type Totals } from '../lib/stats';
import { Avatar, Card, Icon, Loading, Page, Pill, RefreshButton, Seg, useLoad } from '../ui';

type Filter = 'all' | 'active' | 'inactive' | 'no-desktop' | 'suspended';
type Sort = 'seen' | 'tokens' | 'email';

export function Users() {
  const days = lastDays(30);
  const state = useLoad(async () => {
    const [users, daily, crashes] = await Promise.all([loadUsers(), loadDailySince(days[0]), loadCrashes()]);
    return { users, usage: totalsByUser(daily, new Set(days)), crashes };
  });
  return (
    <Page title="Người dùng" sub="Tài khoản đã dùng app điện thoại hoặc desktop" actions={<RefreshButton onClick={state.reload} loading={state.loading} />}>
      <Loading state={state}>{(d) => <UserTable {...d} />}</Loading>
    </Page>
  );
}

function UserTable({ users, usage, crashes }: { users: UserRow[]; usage: Map<string, Totals>; crashes: CrashRow[] }) {
  const [q, setQ] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [sort, setSort] = useState<Sort>('seen');
  const go = useNavigate();
  const now = new Date();
  const openCrashes = useMemo(() => {
    const m = new Map<string, number>();
    for (const c of crashes) if (c.status === 'open') m.set(c.uid, (m.get(c.uid) ?? 0) + 1);
    return m;
  }, [crashes]);
  const active = (u: UserRow) => within(u.lastSeenAt, 7, now) || within(u.lastSyncAt, 7, now);
  const count = (f: Filter) => users.filter((u) => matches(u, f)).length;
  function matches(u: UserRow, f: Filter) {
    switch (f) {
      case 'active': return active(u);
      case 'inactive': return !active(u);
      case 'suspended': return u.suspended !== null;
      case 'no-desktop': return u.lastSyncAt === null;
      default: return true;
    }
  }
  const t = (u: UserRow) => usage.get(u.uid) ?? emptyTotals();
  const rows = users
    .filter((u) => matches(u, filter) && (!q || `${u.email ?? ''} ${u.displayName ?? ''} ${u.uid} ${u.desktopName ?? ''}`.toLowerCase().includes(q.toLowerCase())))
    .sort((a, b) => {
      if (sort === 'email') return (a.email ?? a.uid).localeCompare(b.email ?? b.uid);
      if (sort === 'tokens') return tokens(t(b)) - tokens(t(a));
      const last = (u: UserRow) => Math.max(u.lastSeenAt?.getTime() ?? 0, u.lastSyncAt?.getTime() ?? 0);
      return last(b) - last(a);
    });

  const exportCsv = () => {
    const head = ['uid', 'email', 'name', 'desktop', 'mobile_version', 'last_seen', 'last_sync', 'tokens_30d', 'cost_usd_30d', 'suspended'];
    const lines = rows.map((u) =>
      [u.uid, u.email ?? '', u.displayName ?? '', u.desktopName ?? '', u.mobileVersion ?? '', u.lastSeenAt?.toISOString() ?? '', u.lastSyncAt?.toISOString() ?? '', tokens(t(u)), ((t(u).costMicro ?? 0) / 1e6).toFixed(2), u.suspended ? 'yes' : '']
        .map((v) => `"${String(v).replace(/"/g, '""')}"`).join(','));
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([[head.join(','), ...lines].join('\n')], { type: 'text/csv' }));
    a.download = `utoken-users-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
  };

  return (
    <Card>
      <div className="toolbar">
        <div className="search">
          <Icon name="search" />
          <input className="input" placeholder="Tìm email, tên, UID, tên máy…" value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
        <Seg value={filter} onChange={setFilter} options={[
          ['all', `Tất cả ${users.length}`], ['active', `Hoạt động ${count('active')}`], ['inactive', `Ngừng ${count('inactive')}`],
          ['no-desktop', `Chưa có desktop ${count('no-desktop')}`], ['suspended', `Bị khóa ${count('suspended')}`],
        ]} />
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 8 }}>
          <select className="input" value={sort} onChange={(e) => setSort(e.target.value as Sort)} aria-label="Sắp xếp">
            <option value="seen">Mới hoạt động</option>
            <option value="tokens">Nhiều token nhất</option>
            <option value="email">Email A→Z</option>
          </select>
          <button className="btn" onClick={exportCsv}><Icon name="download" /> CSV</button>
        </div>
      </div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>Người dùng</th><th>Thiết bị</th><th>Mở app</th><th>Sync</th><th className="num">Token 30 ngày</th><th className="num">Chi phí</th><th>Trạng thái</th></tr>
          </thead>
          <tbody>
            {rows.map((u) => {
              const crashes = openCrashes.get(u.uid) ?? 0;
              return (
                <tr key={u.uid} className="click" onClick={() => go(`/users/${u.uid}`)}>
                  <td>
                    <div className="who">
                      <Avatar name={u.email ?? u.uid} />
                      <div style={{ minWidth: 0 }}>
                        <Link to={`/users/${u.uid}`} style={{ color: 'var(--text)' }} onClick={(e) => e.stopPropagation()}>{u.email ?? <span className="mono">{u.uid}</span>}</Link>
                        <div className="muted small">{u.displayName ?? (u.email ? '' : 'Chưa có email — app cũ')}</div>
                      </div>
                    </div>
                  </td>
                  <td className="small">
                    <div><Icon name="chip" size={12} /> {u.desktopName ?? <span className="faint">—</span>}</div>
                    <div className="muted"><Icon name="phone" size={12} /> {u.mobileVersion ? `${u.mobilePlatform ?? ''} ${u.mobileVersion}` : <span className="faint">—</span>}</div>
                  </td>
                  <td className="muted">{fmtAgo(u.lastSeenAt, now)}</td>
                  <td className="muted">{fmtAgo(u.lastSyncAt, now)}</td>
                  <td className="num">{fmtTokens(tokens(t(u)))}</td>
                  <td className="num">{fmtUsd(t(u).costMicro ?? 0)}</td>
                  <td>
                    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                      {u.suspended ? <Pill tone="bad">Đã khóa</Pill> : active(u) ? <Pill tone="good">Hoạt động</Pill> : <Pill>Ngừng</Pill>}
                      {crashes > 0 && <Pill tone="warn">{crashes} crash</Pill>}
                    </div>
                  </td>
                </tr>
              );
            })}
            {rows.length === 0 && <tr><td colSpan={7} className="empty">Không có người dùng phù hợp.</td></tr>}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
