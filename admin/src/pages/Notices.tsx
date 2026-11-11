import { useState } from 'react';
import { Link } from 'react-router-dom';
import { deactivateNotice, loadNotices, loadUsers, sendNotice, type NoticeLevel, type NoticeRow, type UserRow } from '../lib/data';
import { fmtAgo, fmtDateTime } from '../lib/stats';
import { Card, Dialog, Icon, Loading, Page, Pill, RefreshButton, Seg, friendlyError, useLoad } from '../ui';

const levelText: Record<NoticeLevel, string> = { info: 'Thông tin', warning: 'Cảnh báo', critical: 'Khẩn cấp' };
const levelTone = (l: NoticeLevel) => (l === 'critical' ? 'bad' : l === 'warning' ? 'warn' : undefined);

export function Notices() {
  const state = useLoad(async () => {
    const [notices, users] = await Promise.all([loadNotices(), loadUsers()]);
    return { notices, users };
  });
  return (
    <Page title="Thông báo" sub="Gửi tin tới app điện thoại của người dùng: tất cả hoặc một người." actions={<RefreshButton onClick={state.reload} loading={state.loading} />}>
      <Loading state={state}>{({ notices, users }) => <Body notices={notices} users={users} reload={state.reload} />}</Loading>
    </Page>
  );
}

function Body({ notices, users, reload }: { notices: NoticeRow[]; users: UserRow[]; reload: () => void }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [level, setLevel] = useState<NoticeLevel>('info');
  const [audience, setAudience] = useState<'all' | 'one'>('all');
  const [target, setTarget] = useState('');
  const [expires, setExpires] = useState('');
  const [confirm, setConfirm] = useState(false);
  const [off, setOff] = useState<NoticeRow | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const [show, setShow] = useState<'active' | 'all'>('active');

  const emails = new Map(users.map((u) => [u.uid, u.email ?? u.uid]));
  const targetUser = users.find((u) => u.uid === target);
  const valid = title.trim().length > 0 && title.length <= 80 && body.trim().length > 0 && body.length <= 1000 && (audience === 'all' || targetUser);
  const rows = notices.filter((n) => show === 'all' || (n.active && (!n.expiresAt || n.expiresAt > new Date())));

  return (
    <>
      <div className="grid two">
        <Card title="Soạn thông báo">
          <div style={{ display: 'grid', gap: 12 }}>
            <label className="small muted">Gửi tới</label>
            <Seg value={audience} onChange={setAudience} options={[['all', `Tất cả người dùng (${users.length})`], ['one', 'Một người']]} />
            {audience === 'one' && (
              <select className="input" value={target} onChange={(e) => setTarget(e.target.value)} aria-label="Người nhận">
                <option value="">Chọn người nhận…</option>
                {users.filter((u) => u.email).sort((a, b) => a.email!.localeCompare(b.email!)).map((u) => <option key={u.uid} value={u.uid}>{u.email}</option>)}
              </select>
            )}
            <label className="small muted">Mức độ</label>
            <Seg value={level} onChange={setLevel} options={[['info', 'Thông tin'], ['warning', 'Cảnh báo'], ['critical', 'Khẩn cấp']]} />
            <label className="small muted">Tiêu đề <span className="faint">({title.length}/80)</span></label>
            <input className="input" maxLength={80} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Ví dụ: Bảo trì đồng bộ tối nay" />
            <label className="small muted">Nội dung <span className="faint">({body.length}/1000)</span></label>
            <textarea className="input" rows={5} maxLength={1000} value={body} onChange={(e) => setBody(e.target.value)} placeholder="Nội dung người dùng sẽ thấy trên điện thoại." />
            <label className="small muted">Tự ẩn sau (không bắt buộc)</label>
            <input className="input" type="datetime-local" value={expires} onChange={(e) => setExpires(e.target.value)} />
            {error && <div className="error">{error}</div>}
            {sent && <div className="small" style={{ color: 'var(--green)' }}><Icon name="check" size={13} /> Đã gửi. Người dùng thấy ngay khi mở app.</div>}
            <div><button className="btn primary" disabled={!valid} onClick={() => { setError(null); setSent(false); setConfirm(true); }}><Icon name="spark" /> Gửi thông báo</button></div>
          </div>
        </Card>
        <Card title="Xem trước" hint="trên điện thoại">
          <div style={{ maxWidth: 360, margin: '0 auto', background: 'var(--page)', border: '1px solid var(--line)', borderRadius: 22, padding: 16 }}>
            <div className="small muted" style={{ marginBottom: 10 }}>Tab Tokens</div>
            <div style={{ background: 'var(--panel)', border: '1px solid var(--line)', borderRadius: 14, padding: 14 }}>
              <div style={{ display: 'flex', gap: 10 }}>
                <span style={{ width: 32, height: 32, borderRadius: 10, display: 'grid', placeItems: 'center', flex: 'none', background: 'var(--raised)', color: level === 'critical' ? 'var(--red)' : level === 'warning' ? 'var(--orange)' : 'var(--blue)' }}><Icon name="alert" /></span>
                <div style={{ minWidth: 0 }}>
                  <b>{title || 'Tiêu đề thông báo'}</b>
                  <div className="muted small" style={{ marginTop: 2, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{body || 'Nội dung thông báo…'}</div>
                </div>
              </div>
              <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
                <span className="btn sm">Chi tiết</span><span className="btn sm">Ẩn</span>
              </div>
            </div>
          </div>
        </Card>
      </div>
      <Card title="Đã gửi" right={<Seg value={show} onChange={setShow} options={[['active', 'Đang hiển thị'], ['all', 'Tất cả']]} />}>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Lúc</th><th>Thông báo</th><th>Gửi tới</th><th>Trạng thái</th><th /></tr></thead>
            <tbody>
              {rows.map((n) => {
                const expired = n.expiresAt !== null && n.expiresAt <= new Date();
                return (
                  <tr key={`${n.targetUid ?? 'all'}/${n.id}`}>
                    <td style={{ whiteSpace: 'nowrap' }}>{fmtDateTime(n.createdAt)}<div className="muted small">{fmtAgo(n.createdAt)}</div></td>
                    <td>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}><Pill tone={levelTone(n.level)}>{levelText[n.level]}</Pill><b>{n.title}</b></div>
                      <div className="muted small ellipsis" style={{ marginTop: 6 }} title={n.body}>{n.body}</div>
                    </td>
                    <td>{n.targetUid ? <Link to={`/users/${n.targetUid}`}>{emails.get(n.targetUid) ?? n.targetUid}</Link> : <span>Tất cả</span>}</td>
                    <td>
                      {!n.active ? <Pill>Đã tắt</Pill> : expired ? <Pill>Hết hạn</Pill> : <Pill tone="good">Đang hiển thị</Pill>}
                      {n.expiresAt && !expired && n.active && <div className="muted small">đến {fmtDateTime(n.expiresAt)}</div>}
                    </td>
                    <td className="num">{n.active && !expired && <button className="btn sm danger" onClick={() => setOff(n)}>Tắt</button>}</td>
                  </tr>
                );
              })}
              {rows.length === 0 && <tr><td colSpan={5} className="empty">Chưa có thông báo nào.</td></tr>}
            </tbody>
          </table>
        </div>
      </Card>
      {confirm && (
        <Dialog
          title="Gửi thông báo?"
          message={audience === 'all' ? `Tất cả ${users.length} người dùng sẽ thấy "${title}" trên điện thoại.` : `Chỉ ${targetUser?.email} thấy "${title}".`}
          confirm="Gửi"
          onClose={() => setConfirm(false)}
          onConfirm={async () => {
            try {
              await sendNotice({ title: title.trim(), body: body.trim(), level, targetUid: audience === 'one' ? target : null, expiresAt: expires ? new Date(expires) : null });
              setTitle(''); setBody(''); setExpires(''); setSent(true);
              reload();
            } catch (e) {
              setError(friendlyError(e));
              throw e;
            }
          }}
        />
      )}
      {off && (
        <Dialog
          title="Tắt thông báo?"
          message={`"${off.title}" sẽ biến mất khỏi app của người dùng. Không xóa được, chỉ tắt (vẫn lưu lịch sử).`}
          confirm="Tắt thông báo"
          danger
          onClose={() => setOff(null)}
          onConfirm={async () => { await deactivateNotice(off); reload(); }}
        />
      )}
    </>
  );
}
