import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { loadUser, loadUserCrashes, loadUserDaily, loadUserInsight, loadUserSyncRequests, suspendUser, unsuspendUser } from '../lib/data';
import { projectId } from '../lib/firebase';
import { addTotals, emptyTotals, fmtAgo, fmtDateTime, fmtTokens, fmtUsd, lastDays, pct, seriesByDay, tokens, totalsByKeyPart } from '../lib/stats';
import { Avatar, Bars, Card, Dialog, HBars, Icon, Loading, Page, Pill, RefreshButton, Stat, providerName, syncStateText, syncTone, triggerText, useLoad } from '../ui';

export function UserDetail() {
  const { uid = '' } = useParams();
  const days = lastDays(30);
  const state = useLoad(async () => {
    const [user, daily, syncs, crashes, insight] = await Promise.all([
      loadUser(uid), loadUserDaily(uid, days[0]), loadUserSyncRequests(uid), loadUserCrashes(uid), loadUserInsight(uid),
    ]);
    return { user, daily, syncs, crashes, insight };
  }, [uid]);
  const [dialog, setDialog] = useState<'suspend' | 'unsuspend' | null>(null);

  return (
    <Loading state={state}>
      {({ user, daily, syncs, crashes, insight }) => {
        if (!user)
          return (
            <Page title="Không tìm thấy" sub={uid}>
              <Card><div className="empty">Không có users/{uid}. <Link to="/users">Quay lại danh sách</Link></div></Card>
            </Page>
          );
        const series = seriesByDay(daily, days);
        const total = daily.reduce((s, d) => addTotals(s, d.totals), emptyTotals());
        const daySet = new Set(days);
        const openCrashes = crashes.filter((c) => c.status === 'open').length;
        return (
          <Page
            title={user.email ?? 'Người dùng'}
            sub={<span className="mono">{uid}</span>}
            actions={
              <>
                <Link className="btn" to="/users"><Icon name="back" /> Danh sách</Link>
                <RefreshButton onClick={state.reload} loading={state.loading} />
              </>
            }
          >
            {user.suspended && (
              <div className="banner bad">
                <Icon name="lock" />
                <div>
                  Tài khoản đang <b>bị khóa</b> từ {fmtDateTime(user.suspended.at)}. Lý do: {user.suspended.reason || '—'}.
                  <div className="muted small">Người dùng không đọc/ghi được dữ liệu của mình trên điện thoại và desktop cho tới khi mở khóa.</div>
                </div>
              </div>
            )}
            <div className="grid two">
              <Card title="Hồ sơ" right={user.suspended ? <Pill tone="bad">Đã khóa</Pill> : <Pill tone="good">Đang hoạt động</Pill>}>
                <div className="who" style={{ marginBottom: 18 }}>
                  <Avatar name={user.email ?? uid} />
                  <div><b>{user.displayName ?? '—'}</b><div className="muted small">{user.email ?? 'Chưa có email (app cũ)'}</div></div>
                </div>
                <dl className="kv">
                  <dt>Máy tính</dt><dd>{user.desktopName ?? '—'}{user.desktopOs && <div className="muted small">{user.desktopOs}</div>}</dd>
                  <dt>Điện thoại</dt><dd>{user.mobileVersion ? `${user.mobilePlatform ?? ''} · v${user.mobileVersion}` : '—'}</dd>
                  <dt>Mở app gần nhất</dt><dd>{fmtDateTime(user.lastSeenAt)} <span className="muted">· {fmtAgo(user.lastSeenAt)}</span></dd>
                  <dt>Sync gần nhất</dt><dd>{fmtDateTime(user.lastSyncAt)} <span className="muted">· {fmtAgo(user.lastSyncAt)}</span></dd>
                </dl>
                <div className="toolbar" style={{ marginTop: 20, marginBottom: 0 }}>
                  {user.suspended
                    ? <button className="btn" onClick={() => setDialog('unsuspend')}><Icon name="unlock" /> Mở khóa</button>
                    : <button className="btn danger" onClick={() => setDialog('suspend')}><Icon name="lock" /> Khóa tài khoản</button>}
                  <a className="btn" target="_blank" rel="noreferrer" href={`https://console.firebase.google.com/project/${projectId}/firestore/databases/-default-/data/~2Fusers~2F${uid}`}><Icon name="external" /> Firestore</a>
                </div>
              </Card>
              <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(170px, 1fr))', alignContent: 'start' }}>
                <Stat label="Token 30 ngày" value={fmtTokens(tokens(total))} sub={`${total.chats} chat`} />
                <Stat label="Chi phí 30 ngày" value={fmtUsd(total.costMicro)} />
                <Stat label="Cache hit" value={pct(total.cached, total.input)} />
                <Stat label="Request lỗi" value={pct(total.errorRequests, total.requests)} tone={total.errorRequests ? 'warn' : undefined} />
                <Stat label="Điểm AI review" value={insight?.score ?? '—'} sub={insight ? `Hạng ${insight.grade ?? '—'} · ${fmtAgo(insight.generatedAt)}` : 'Chưa có'} />
                <Stat label="Crash chưa xử lý" value={openCrashes} tone={openCrashes ? 'bad' : 'good'} />
              </div>
            </div>
            <div className="grid two">
              <Card title="Token mỗi ngày" hint="30 ngày">
                <Bars values={series.map((d) => tokens(d.totals))} labels={days} format={fmtTokens} />
              </Card>
              <Card title="Công cụ và model">
                <HBars rows={totalsByKeyPart(daily, daySet, 0).map(([k, t]) => [providerName(k), tokens(t)])} format={fmtTokens} />
                <div style={{ height: 1, background: 'var(--line)', margin: '12px 0' }} />
                <HBars rows={totalsByKeyPart(daily, daySet, 1).slice(0, 6).map(([k, t]) => [k, tokens(t)])} format={fmtTokens} />
              </Card>
              <Card title="Yêu cầu đồng bộ" hint={`${syncs.length} gần nhất · ${syncs.filter((s) => s.state === 'failed').length} lỗi`}>
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>Lúc</th><th>Nguồn</th><th>Trạng thái</th></tr></thead>
                    <tbody>
                      {syncs.map((s) => (
                        <tr key={s.id}>
                          <td>{fmtDateTime(s.createdAt)}</td>
                          <td className="muted">{triggerText[s.trigger] ?? s.trigger}</td>
                          <td><Pill tone={syncTone(s.state)}>{syncStateText[s.state] ?? s.state}</Pill> {s.errorCode && <span className="mono muted">{s.errorCode}</span>}</td>
                        </tr>
                      ))}
                      {syncs.length === 0 && <tr><td colSpan={3} className="empty">Chưa có.</td></tr>}
                    </tbody>
                  </table>
                </div>
              </Card>
              <Card title="Crash" right={<Link to="/crashes" className="small">Trang Crash →</Link>}>
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>Lúc</th><th>Nội dung</th><th>Trạng thái</th></tr></thead>
                    <tbody>
                      {crashes.map((c) => (
                        <tr key={c.id}>
                          <td style={{ whiteSpace: 'nowrap' }}>{fmtDateTime(c.createdAt)}<div className="muted small">{c.platform} {c.appVersion}</div></td>
                          <td><div className="ellipsis" title={c.message}>{c.message || c.type}</div><div className="muted small">{c.type}{c.screen ? ` · ${c.screen}` : ''}</div></td>
                          <td>{c.status === 'open' ? <Pill tone="warn">Chưa xử lý</Pill> : <Pill tone="good">Đã xử lý</Pill>}</td>
                        </tr>
                      ))}
                      {crashes.length === 0 && <tr><td colSpan={3} className="empty">Không có crash.</td></tr>}
                    </tbody>
                  </table>
                </div>
              </Card>
            </div>
            {insight && (
              <Card title="AI review hiện tại" hint={`${providerName(insight.provider)} · ${insight.model} · ${insight.source === 'phone' ? 'chạy trên điện thoại' : 'chạy trên desktop'}`}>
                <p style={{ margin: 0, fontSize: 15 }}>{insight.headline || <span className="muted">—</span>}</p>
                <p className="muted small" style={{ marginBottom: 0 }}>{insight.insightCount} gợi ý · trạng thái {insight.status}{insight.errorCode ? ` · lỗi ${insight.errorCode}` : ''}</p>
              </Card>
            )}
            {dialog === 'suspend' && (
              <Dialog
                title={`Khóa ${user.email ?? uid}?`}
                message="Người dùng sẽ mất quyền đọc và ghi dữ liệu của mình cho tới khi được mở khóa. Lý do được lưu vào nhật ký admin."
                input inputLabel="Lý do (bắt buộc)" required danger confirm="Khóa tài khoản"
                onClose={() => setDialog(null)}
                onConfirm={async (reason) => { await suspendUser(uid, reason); state.reload(); }}
              />
            )}
            {dialog === 'unsuspend' && (
              <Dialog
                title={`Mở khóa ${user.email ?? uid}?`}
                message="Người dùng sẽ dùng lại được app ngay."
                confirm="Mở khóa"
                onClose={() => setDialog(null)}
                onConfirm={async () => { await unsuspendUser(uid); state.reload(); }}
              />
            )}
          </Page>
        );
      }}
    </Loading>
  );
}
