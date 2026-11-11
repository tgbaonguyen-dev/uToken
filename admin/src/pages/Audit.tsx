import { Link } from 'react-router-dom';
import { loadAudit } from '../lib/data';
import { fmtDateTime } from '../lib/stats';
import { Loading, Page, useLoad, RefreshButton } from '../ui';

const actionText: Record<string, string> = {
  suspend_user: 'Khóa tài khoản',
  unsuspend_user: 'Mở khóa tài khoản',
  resolve_crash: 'Đóng crash',
  reopen_crash: 'Mở lại crash',
  send_notice: 'Gửi thông báo',
  deactivate_notice: 'Tắt thông báo',
};

export function Audit() {
  const state = useLoad(() => loadAudit());
  return (
    <Page title="Nhật ký admin" sub="Mọi thao tác thay đổi dữ liệu từ trang này. Chỉ thêm, không sửa/xóa được." actions={<RefreshButton onClick={state.reload} loading={state.loading} />}>
      <Loading state={state}>
        {(rows) => (
          <div className="card table-wrap">
            <table>
              <thead><tr><th>Lúc</th><th>Admin</th><th>Thao tác</th><th>Đối tượng</th><th>Chi tiết</th></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td>{fmtDateTime(r.at)}</td>
                    <td>{r.actorEmail || <span className="mono">{r.actorUid}</span>}</td>
                    <td>{actionText[r.action] ?? r.action}</td>
                    <td>{r.targetUid ? <Link className="mono" to={`/users/${r.targetUid}`}>{r.targetUid}</Link> : '—'}</td>
                    <td>{r.detail}</td>
                  </tr>
                ))}
                {rows.length === 0 && <tr><td colSpan={5} className="empty">Chưa có thao tác nào.</td></tr>}
              </tbody>
            </table>
          </div>
        )}
      </Loading>
    </Page>
  );
}
