import { useState } from 'react';
import { Link } from 'react-router-dom';
import { loadSyncRequests, loadUsers } from '../lib/data';
import { dayKey, fmtAgo, fmtDateTime, isStuck, lastDays, pct, syncHealth, within } from '../lib/stats';
import { Bars, Card, HBars, Loading, Page, Pill, RefreshButton, Seg, Stat, syncStateText, syncTone, triggerText, useLoad } from '../ui';

const errorText: Record<string, string> = {
  companion_offline: 'Desktop không phản hồi',
  network: 'Desktop mất mạng',
  revoked: 'Desktop cần đăng nhập lại',
  not_paired: 'Desktop chưa đăng nhập',
  timeout: 'Hết thời gian',
  unknown: 'Không rõ',
};

export function Sync() {
  const state = useLoad(async () => {
    const [syncs, users] = await Promise.all([loadSyncRequests(1000), loadUsers()]);
    return { syncs, emails: new Map(users.map((u) => [u.uid, u.email ?? u.uid])) };
  });
  const [range, setRange] = useState(7);
  const [only, setOnly] = useState<'all' | 'failed' | 'stuck'>('all');

  return (
    <Page
      title="Đồng bộ"
      sub="Yêu cầu từ điện thoại nhờ desktop tải dữ liệu mới lên"
      actions={<><Seg value={range} onChange={setRange} options={[[1, '24 giờ'], [7, '7 ngày'], [30, '30 ngày']]} /><RefreshButton onClick={state.reload} loading={state.loading} /></>}
    >
      <Loading state={state}>
        {({ syncs, emails }) => {
          const now = new Date();
          const inRange = syncs.filter((s) => within(s.createdAt, range, now));
          const h = syncHealth(inRange, now);
          const days = lastDays(Math.max(7, Math.min(range, 30)));
          const perDay = (st: string | null) => days.map((d) => inRange.filter((s) => s.createdAt !== null && dayKey(s.createdAt) === d && (st === null || s.state === st)).length);
          const triggers = new Map<string, number>();
          for (const s of inRange) triggers.set(triggerText[s.trigger] ?? s.trigger, (triggers.get(triggerText[s.trigger] ?? s.trigger) ?? 0) + 1);
          const rows = inRange.filter((s) => only === 'all' || (only === 'failed' ? s.state === 'failed' : isStuck(s, now))).slice(0, 200);
          return (
            <>
              <div className="grid kpis">
                <Stat icon="sync" label="Yêu cầu" value={h.total} />
                <Stat icon="check" label="Thành công" value={pct(h.done, h.total)} tone="good" sub={`${h.done} yêu cầu`} />
                <Stat icon="alert" label="Lỗi" value={h.failed} tone={h.failed ? 'bad' : undefined} />
                <Stat label="Đang kẹt" value={h.stuck} tone={h.stuck ? 'bad' : undefined} sub="chờ quá 10 phút" />
                <Stat label="Thời gian xử lý" value={h.medianSeconds === null ? '—' : `${Math.round(h.medianSeconds)}s`} sub="trung vị, gửi → xong" />
              </div>
              <div className="grid two">
                <Card title="Yêu cầu mỗi ngày"><Bars values={perDay(null)} labels={days} format={(v) => `${v} yêu cầu`} /></Card>
                <Card title="Lỗi mỗi ngày"><Bars color="red" values={perDay('failed')} labels={days} format={(v) => `${v} lỗi`} /></Card>
                <Card title="Nguyên nhân lỗi"><HBars rows={h.errors.map(([k, v]) => [errorText[k] ?? k, v])} format={String} /></Card>
                <Card title="Nguồn kích hoạt"><HBars rows={[...triggers.entries()]} format={String} /></Card>
              </div>
              <Card>
                <div className="toolbar">
                  <Seg value={only} onChange={setOnly} options={[['all', 'Tất cả'], ['failed', `Lỗi ${h.failed}`], ['stuck', `Kẹt ${h.stuck}`]]} />
                  <span className="muted small" style={{ marginLeft: 'auto' }}>{rows.length} dòng (tối đa 200)</span>
                </div>
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>Lúc</th><th>Người dùng</th><th>Nguồn</th><th>Trạng thái</th><th>Nguyên nhân</th><th>Xong lúc</th></tr></thead>
                    <tbody>
                      {rows.map((s) => {
                        const stuck = isStuck(s, now);
                        return (
                          <tr key={`${s.uid}/${s.id}`}>
                            <td style={{ whiteSpace: 'nowrap' }}>{fmtDateTime(s.createdAt)}<div className="muted small">{fmtAgo(s.createdAt, now)}</div></td>
                            <td><Link to={`/users/${s.uid}`}>{emails.get(s.uid) ?? s.uid}</Link></td>
                            <td className="muted">{triggerText[s.trigger] ?? s.trigger}</td>
                            <td><Pill tone={stuck ? 'bad' : syncTone(s.state)}>{stuck ? 'Bị kẹt' : syncStateText[s.state] ?? s.state}</Pill></td>
                            <td>{s.errorCode ? errorText[s.errorCode] ?? s.errorCode : <span className="faint">—</span>}</td>
                            <td className="muted">{fmtDateTime(s.finishedAt)}</td>
                          </tr>
                        );
                      })}
                      {rows.length === 0 && <tr><td colSpan={6} className="empty">Không có yêu cầu.</td></tr>}
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
