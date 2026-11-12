import { StrictMode, useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { HashRouter, NavLink, Navigate, Route, Routes, useLocation, Link } from 'react-router-dom';
import { onAuthStateChanged, signInWithEmailAndPassword, signInWithPopup, signOut, type User } from 'firebase/auth';
import { auth, google, projectId } from './lib/firebase';
import { isAdmin, loadCrashes } from './lib/data';
import { Overview } from './pages/Overview';
import { Users } from './pages/Users';
import { UserDetail } from './pages/UserDetail';
import { Crashes } from './pages/Crashes';
import { Sync } from './pages/Sync';
import { Reviews } from './pages/Reviews';
import { Audit } from './pages/Audit';
import { Admins } from './pages/Admins';
import { Notices } from './pages/Notices';
import { Avatar, Icon, friendlyError } from './ui';
import './styles.css';

type Gate = { state: 'loading' } | { state: 'signedOut' } | { state: 'denied'; user: User } | { state: 'admin'; user: User };

const nav: [string, string, string][] = [
  ['/', 'Tổng quan', 'home'],
  ['/users', 'Người dùng', 'users'],
  ['/crashes', 'Crash', 'bug'],
  ['/sync', 'Đồng bộ', 'sync'],
  ['/reviews', 'AI review', 'spark'],
  ['/notices', 'Thông báo', 'bell'],
  ['/audit', 'Nhật ký admin', 'log'],
  ['/admins', 'Quản trị viên', 'shield'],
];

function Logo() {
  return (
    <div className="logo">
      <span className="logo-mark">μ</span>
      <b>μToken</b>
      <small>ADMIN</small>
    </div>
  );
}

function GoogleMark() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden>
      <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z" />
      <path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" />
      <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z" />
      <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z" />
    </svg>
  );
}

function Login({ gate, error, onLogin, onError }: { gate: Gate; error: string | null; onLogin: () => void; onError: (e: string) => void }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="login-wrap">
      <div className="card login">
        <Logo />
        {gate.state === 'denied' ? (
          <>
            <h1>Chưa có quyền admin</h1>
            <p>
              <b style={{ color: 'var(--text)' }}>{gate.user.email}</b> đã đăng nhập nhưng chưa là quản trị viên. Tạo document{' '}
              <span className="mono">admins/&lt;UID&gt;</span> (trường <span className="mono">email</span>) trong Firestore, rồi tải lại trang.
            </p>
            <div className="input mono" style={{ display: 'flex', alignItems: 'center', marginBottom: 10 }}>{gate.user.uid}</div>
            <div style={{ display: 'grid', gap: 8 }}>
              <button className="btn primary" onClick={() => { navigator.clipboard?.writeText(gate.user.uid); setCopied(true); }}>
                <Icon name="check" /> {copied ? 'Đã sao chép UID' : 'Sao chép UID'}
              </button>
              <a className="btn" target="_blank" rel="noreferrer" href={`https://console.firebase.google.com/project/${projectId}/firestore/databases/-default-/data`}>
                <Icon name="external" /> Mở Firestore trong Firebase Console
              </a>
              <button className="btn" onClick={() => location.reload()}><Icon name="refresh" /> Tải lại</button>
              <button className="btn" onClick={() => signOut(auth)}><Icon name="logout" /> Đăng xuất</button>
            </div>
          </>
        ) : (
          <>
            <h1>Bảng điều khiển quản trị</h1>
            <p>Theo dõi người dùng, đồng bộ desktop, crash và AI review của μToken. Chỉ tài khoản được cấp quyền mới xem được dữ liệu.</p>
            <button className="btn white gbtn" onClick={onLogin}><GoogleMark /> Đăng nhập bằng Google</button>
            {import.meta.env.VITE_USE_EMULATOR === '1' && (
              // Emulator only: lets local tests sign in without the Google popup.
              <form
                style={{ marginTop: 16, display: 'grid', gap: 8 }}
                onSubmit={(e) => {
                  e.preventDefault();
                  const f = new FormData(e.currentTarget);
                  signInWithEmailAndPassword(auth, String(f.get('email')), String(f.get('password'))).catch((err) => onError(friendlyError(err)));
                }}
              >
                <input className="input" name="email" placeholder="email (emulator)" />
                <input className="input" name="password" type="password" placeholder="mật khẩu" />
                <button className="btn" type="submit">Đăng nhập emulator</button>
              </form>
            )}
          </>
        )}
        {error && <div className="error">{error}</div>}
      </div>
    </div>
  );
}

function Shell({ user }: { user: User }) {
  const loc = useLocation();
  const [openCrashes, setOpenCrashes] = useState<number | null>(null);
  useEffect(() => {
    loadCrashes().then((c) => setOpenCrashes(c.filter((x) => x.status === 'open').length)).catch(() => setOpenCrashes(null));
  }, [loc.pathname]);
  const section = nav.find(([to]) => (to === '/' ? loc.pathname === '/' : loc.pathname.startsWith(to))) ?? nav[0];
  const sub = loc.pathname.startsWith('/users/') ? 'Chi tiết' : null;
  return (
    <div className="shell">
      <header className="topbar">
        <Logo />
        <div className="crumbs">
          {sub ? (<><Link to={section[0]}>{section[1]}</Link><span className="sep">›</span><b>{sub}</b></>) : <b>{section[1]}</b>}
        </div>
        <div className="top-actions">
          <span className="status"><span className={`dot ${openCrashes ? 'bad' : ''}`} />{openCrashes === null ? 'Đang kết nối…' : openCrashes ? `${openCrashes} crash chưa xử lý` : 'Hệ thống ổn định'}</span>
          <button className="account" onClick={() => signOut(auth)} title="Đăng xuất">
            <Avatar name={user.displayName ?? user.email ?? '?'} photo={user.photoURL} />
            <span>{user.email}</span>
            <Icon name="logout" size={14} />
          </button>
        </div>
      </header>
      <div className="body">
        <aside className="side">
          <nav className="nav">
            {nav.map(([to, label, icon]) => (
              <NavLink key={to} to={to} end={to === '/'}>
                <Icon name={icon} /> {label}
                {to === '/crashes' && openCrashes ? <span className="count">{openCrashes}</span> : null}
              </NavLink>
            ))}
          </nav>
          <div className="side-card">
            <b>Firebase · {projectId}</b>
            Dữ liệu đọc trực tiếp từ Firestore. Mọi thay đổi được ghi vào nhật ký admin.
          </div>
        </aside>
        <main>
          <Routes>
            <Route path="/" element={<Overview />} />
            <Route path="/users" element={<Users />} />
            <Route path="/users/:uid" element={<UserDetail />} />
            <Route path="/crashes" element={<Crashes />} />
            <Route path="/sync" element={<Sync />} />
            <Route path="/reviews" element={<Reviews />} />
            <Route path="/notices" element={<Notices />} />
            <Route path="/audit" element={<Audit />} />
            <Route path="/admins" element={<Admins />} />
            <Route path="*" element={<Navigate to="/" />} />
          </Routes>
        </main>
      </div>
    </div>
  );
}

function App() {
  const [gate, setGate] = useState<Gate>({ state: 'loading' });
  const [error, setError] = useState<string | null>(null);

  useEffect(
    () =>
      onAuthStateChanged(auth, async (user) => {
        if (!user) return setGate({ state: 'signedOut' });
        setGate((await isAdmin(user.uid)) ? { state: 'admin', user } : { state: 'denied', user });
      }),
    [],
  );

  const login = async () => {
    setError(null);
    try {
      await signInWithPopup(auth, google);
    } catch (e) {
      if ((e as { code?: string }).code !== 'auth/popup-closed-by-user') setError(friendlyError(e));
    }
  };

  if (gate.state === 'loading') return <div className="login-wrap muted">Đang kiểm tra phiên đăng nhập…</div>;
  if (gate.state !== 'admin') return <Login gate={gate} error={error} onLogin={login} onError={setError} />;
  return (
    <HashRouter>
      <Shell user={gate.user} />
    </HashRouter>
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
