import { Fragment, useState } from 'react';
import { Link } from 'react-router-dom';
import { loadCrashes, loadUsers, setCrashStatus } from '../lib/data';
import { projectId } from '../lib/firebase';
import { dayKey, fmtAgo, fmtDateTime, lastDays, type CrashRow } from '../lib/stats';
import { Bars, Card, Dialog, HBars, Icon, Loading, Page, Pill, RefreshButton, Seg, Stat, useLoad } from '../ui';

const typeText: Record<string, string> = { test_crash: 'Crash thử', fatal_error: 'Lỗi nghiêm trọng', error: 'Lỗi', flutter_error: 'Lỗi Flutter' };

export function Crashes() {
  const state = useLoad(async () => {
    const [crashes, users] = await Promise.all([loadCrashes(), loadUsers()]);
    return { crashes, emails: new Map(users.map((u) => [u.uid, u.email ?? u.uid])) };
  });
  const [status, setStatus] = useState<'open' | 'resolved' | 'all'>('open');
  const [hideTests, setHideTests] = useState(false);
  const [version, setVersion] = useState('all');
  const [open, setOpen] = useState<string | null>(null);
  const [dialog, setDialog] = useState<{ crash: CrashRow; next: 'open' | 'resolved' } | null>(null);

  return (
    <Page
      title="Crash"
      sub="Lỗi app tự gửi về (và crash thử từ Cài đặt). Stack trace đầy đủ, ANR và crash native xem ở Crashlytics."
      actions={
        <>
          <a className="btn" target="_blank" rel="noreferrer" href={`https://console.firebase.google.com/project/${projectId}/crashlytics`}><Icon name="external" /> Crashlytics</a>
          <RefreshButton onClick={state.reload} loading={state.loading} />
        </>
      }
    >
      <Loading state={state}>
        {({ crashes, emails }) => {
          const ver = (c: CrashRow) => `${c.platform} ${c.appVersion}`.trim() || 'không rõ';
          const versions = [...new Set(crashes.map(ver))].sort();
          const openList = crashes.filter((c) => c.status === 'open');
          const rows = crashes.filter((c) => (status === 'all' || c.status === status) && (version === 'all' || ver(c) === version) && (!hideTests || c.type !== 'test_crash'));
          const group = (key: (c: CrashRow) => string) => {
            const m = new Map<string, number>();
            for (const c of openList) m.set(key(c), (m.get(key(c)) ?? 0) + 1);
            return [...m.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6);
          };
          const days = lastDays(14);
          const perDay = days.map((d) => crashes.filter((c) => c.createdAt !== null && dayKey(c.createdAt) === d).length);
          return (
            <>
              <div className="grid kpis">
                <Stat icon="bug" label="Chưa xử lý" value={openList.length} tone={openList.length ? 'bad' : 'good'} sub={`${openList.filter((c) => c.type !== 'test_crash').length} lỗi thật`} />
                <Stat icon="users" label="Người bị ảnh hưởng" value={new Set(openList.map((c) => c.uid)).size} />
                <Stat icon="check" label="Đã xử lý" value={crashes.filter((c) => c.status === 'resolved').length} tone="good" />
                <Stat icon="alert" label="Gần nhất" value={<span style={{ fontSize: 20 }}>{crashes[0] ? fmtAgo(crashes[0].createdAt) : '—'}</span>} sub={crashes[0] ? typeText[crashes[0].type] ?? crashes[0].type : 'Chưa có báo cáo'} />
              </div>
              <div className="grid two">
                <Card title="Crash mỗi ngày" hint="14 ngày"><Bars color="red" values={perDay} labels={days} format={(v) => `${v} báo cáo`} /></Card>
                <Card title="Chưa xử lý theo phiên bản / màn hình">
                  <HBars rows={group(ver)} format={String} />
                  <div style={{ height: 1, background: 'var(--line)', margin: '12px 0' }} />
                  <HBars rows={group((c) => c.screen || 'không rõ')} format={String} />
                </Card>
              </div>
              <Card>
                <div className="toolbar">
                  <Seg value={status} onChange={setStatus} options={[['open', `Chưa xử lý ${openList.length}`], ['resolved', 'Đã xử lý'], ['all', 'Tất cả']]} />
                  <select className="input" value={version} onChange={(e) => setVersion(e.target.value)} aria-label="Phiên bản">
                    <option value="all">Mọi phiên bản</option>
                    {versions.map((v) => <option key={v} value={v}>{v}</option>)}
                  </select>
                  <label className="muted small" style={{ display: 'flex', gap: 6, alignItems: 'center', cursor: 'pointer' }}>
                    <input type="checkbox" checked={hideTests} onChange={(e) => setHideTests(e.target.checked)} /> Ẩn crash thử
                  </label>
                  <span className="muted small" style={{ marginLeft: 'auto' }}>{rows.length} báo cáo · bấm một dòng để xem chi tiết</span>
                </div>
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>Lúc</th><th>Lỗi</th><th>Người dùng</th><th>Phiên bản</th><th>Trạng thái</th><th /></tr></thead>
                    <tbody>
                      {rows.map((c) => {
                        const key = `${c.uid}/${c.id}`;
                        const expanded = open === key;
                        return (
                          <Fragment key={key}>
                            <tr className={`click ${expanded ? 'expanded' : ''}`} onClick={() => setOpen(expanded ? null : key)}>
                              <td style={{ whiteSpace: 'nowrap' }}>{fmtDateTime(c.createdAt)}<div className="muted small">{fmtAgo(c.createdAt)}</div></td>
                              <td>
                                <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                                  <Pill tone={c.type === 'test_crash' ? undefined : 'bad'}>{typeText[c.type] ?? c.type}</Pill>
                                  {c.screen && <span className="muted small">{c.screen}</span>}
                                </div>
                                <div className="ellipsis" style={{ marginTop: 6 }} title={c.message}>{c.message || <span className="faint">(không có nội dung)</span>}</div>
                              </td>
                              <td><Link to={`/users/${c.uid}`} onClick={(e) => e.stopPropagation()}>{emails.get(c.uid) ?? c.uid}</Link></td>
                              <td className="small">{ver(c)}</td>
                              <td>{c.status === 'open' ? <Pill tone="warn">Chưa xử lý</Pill> : <Pill tone="good">Đã xử lý</Pill>}</td>
                              <td className="num">
                                <button className="btn sm" onClick={(e) => { e.stopPropagation(); setDialog({ crash: c, next: c.status === 'open' ? 'resolved' : 'open' }); }}>
                                  {c.status === 'open' ? <><Icon name="check" size={14} /> Đã xử lý</> : 'Mở lại'}
                                </button>
                              </td>
                            </tr>
                            {expanded && (
                              <tr className="expanded">
                                <td colSpan={6}>
                                  <dl className="kv small">
                                    <dt>Mã báo cáo</dt><dd className="mono">{c.id}</dd>
                                    <dt>UID</dt><dd className="mono">{c.uid}</dd>
                                    <dt>Nội dung</dt><dd>{c.message || '—'}</dd>
                                    {c.adminNote && (<><dt>Ghi chú admin</dt><dd>{c.adminNote} {c.resolvedAt && <span className="muted">· {fmtDateTime(c.resolvedAt)}</span>}</dd></>)}
                                  </dl>
                                  {c.stack ? <pre className="stack mono">{c.stack}</pre> : <div className="muted small" style={{ marginTop: 10 }}>Không có stack trace trong Firestore. Tìm theo UID trên Crashlytics để xem bản đầy đủ.</div>}
                                </td>
                              </tr>
                            )}
                          </Fragment>
                        );
                      })}
                      {rows.length === 0 && <tr><td colSpan={6} className="empty">{status === 'open' ? 'Không có crash nào chưa xử lý 🎉' : 'Không có báo cáo.'}</td></tr>}
                    </tbody>
                  </table>
                </div>
              </Card>
              {dialog && (
                <Dialog
                  title={dialog.next === 'resolved' ? 'Đánh dấu đã xử lý' : 'Mở lại báo cáo'}
                  message={dialog.next === 'resolved' ? 'Ghi chú cách đã xử lý (không bắt buộc), ví dụ "Sửa ở bản 0.1.1".' : 'Báo cáo sẽ quay lại danh sách chưa xử lý.'}
                  input={dialog.next === 'resolved'}
                  inputLabel="Ghi chú"
                  confirm={dialog.next === 'resolved' ? 'Đánh dấu đã xử lý' : 'Mở lại'}
                  onClose={() => setDialog(null)}
                  onConfirm={async (note) => { await setCrashStatus(dialog.crash, dialog.next, note); state.reload(); }}
                />
              )}
            </>
          );
        }}
      </Loading>
    </Page>
  );
}
