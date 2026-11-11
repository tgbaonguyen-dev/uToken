import { loadAdmins } from '../lib/data';
import { projectId } from '../lib/firebase';
import { Loading, Page, useLoad } from '../ui';

export function Admins() {
  const state = useLoad(() => loadAdmins());
  return (
    <Page title="Quản trị viên" sub="Tài khoản có document trong collection admins">
      <div className="banner info"><div>
        Không thể tự cấp quyền admin từ trang này (Rules chặn ghi vào <span className="mono">admins</span>). Để thêm admin: người đó đăng nhập trang này một lần để lấy UID,
        rồi tạo document <span className="mono">admins/&lt;UID&gt;</span> với trường <span className="mono">email</span> trong{' '}
        <a target="_blank" rel="noreferrer" href={`https://console.firebase.google.com/project/${projectId}/firestore/databases/-default-/data/~2Fadmins`}>Firebase Console</a>.
      </div></div>
      <Loading state={state}>
        {(rows) => (
          <div className="card table-wrap">
            <table>
              <thead><tr><th>Email</th><th>UID</th></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.uid}><td>{r.email || '—'}</td><td className="mono">{r.uid}</td></tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Loading>
    </Page>
  );
}
