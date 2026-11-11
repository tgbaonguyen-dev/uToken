import { useCallback, useEffect, useState, type ReactNode } from 'react';

/** Loads async data with loading/error state and a reload function. */
export function useLoad<T>(load: () => Promise<T>, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const run = useCallback(load, deps);
  const reload = useCallback(() => {
    setLoading(true);
    setError(null);
    run()
      .then(setData)
      .catch((e: unknown) => setError(friendlyError(e)))
      .finally(() => setLoading(false));
  }, [run]);
  useEffect(reload, [reload]);
  return { data, error, loading, reload };
}

export function friendlyError(e: unknown): string {
  const code = (e as { code?: string })?.code ?? '';
  if (code === 'permission-denied') return 'Firestore từ chối truy cập. Tài khoản này chưa là admin, hoặc Firestore Rules mới chưa được deploy.';
  if (code === 'failed-precondition') return 'Thiếu index Firestore. Chạy: npx firebase deploy --only firestore:indexes (index mới cần vài phút).';
  if (code === 'unavailable') return 'Không kết nối được Firebase. Kiểm tra mạng.';
  return (e as Error)?.message ?? String(e);
}

// ── Icons (lucide-style strokes) ──
const paths: Record<string, string> = {
  home: 'M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',
  users: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  bug: 'M8 2l1.9 1.9M16 2l-1.9 1.9M9 7.1V6a3 3 0 0 1 6 0v1.1M12 20c-3.3 0-6-2.7-6-6v-3a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v3c0 3.3-2.7 6-6 6M12 20v-9M6.5 13H3M21 13h-3.5M6 9 3.5 7M18 9l2.5-2M6 17l-3 2M18 17l3 2',
  sync: 'M21 12a9 9 0 0 1-15.5 6.2L3 16M3 12a9 9 0 0 1 15.5-6.2L21 8M21 3v5h-5M3 21v-5h5',
  spark: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 17l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z',
  log: 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
  shield: 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10',
  refresh: 'M21 12a9 9 0 1 1-3-6.7L21 8M21 3v5h-5',
  search: 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16M21 21l-4.3-4.3',
  alert: 'M12 9v4M12 17h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0',
  lock: 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4',
  unlock: 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 7.8-1.2',
  external: 'M15 3h6v6M10 14 21 3M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6',
  download: 'M12 3v12M7 10l5 5 5-5M5 21h14',
  check: 'M20 6 9 17l-5-5',
  back: 'M15 18l-6-6 6-6',
  chip: 'M9 3v2M15 3v2M9 19v2M15 19v2M3 9h2M3 15h2M19 9h2M19 15h2M6 5h12v14H6z',
  phone: 'M7 2h10a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1M11 18h2',
  logout: 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9',
  coins: 'M12 7c4.4 0 8-1.3 8-3s-3.6-3-8-3-8 1.3-8 3 3.6 3 8 3M4 4v6c0 1.7 3.6 3 8 3s8-1.3 8-3V4M4 10v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6',
};
export function Icon({ name, size }: { name: keyof typeof paths | string; size?: number }) {
  return (
    <svg className="i" viewBox="0 0 24 24" style={size ? { width: size, height: size } : undefined} aria-hidden>
      <path d={paths[name] ?? ''} />
    </svg>
  );
}

export function Page({ title, sub, actions, children }: { title: string; sub?: ReactNode; actions?: ReactNode; children: ReactNode }) {
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{title}</h1>
          {sub && <p>{sub}</p>}
        </div>
        {actions && <div className="actions">{actions}</div>}
      </div>
      {children}
    </>
  );
}

export function RefreshButton({ onClick, loading }: { onClick: () => void; loading?: boolean }) {
  return (
    <button className="btn" onClick={onClick} disabled={loading}>
      <Icon name="refresh" /> {loading ? 'Đang tải…' : 'Làm mới'}
    </button>
  );
}

export function Loading<T>({ state, children }: { state: { data: T | null; error: string | null; loading: boolean; reload: () => void }; children: (data: T) => ReactNode }) {
  if (state.error)
    return (
      <div className="banner bad">
        <Icon name="alert" />
        <div style={{ flex: 1 }}>
          <div>{state.error}</div>
          <button className="btn sm" style={{ marginTop: 10 }} onClick={state.reload}>Thử lại</button>
        </div>
      </div>
    );
  if (state.loading && state.data === null)
    return (
      <div className="grid kpis">
        {[0, 1, 2, 3].map((i) => <div key={i} className="skeleton" />)}
      </div>
    );
  return <>{state.data !== null && children(state.data)}</>;
}

export function Card({ title, hint, right, children, style }: { title?: ReactNode; hint?: ReactNode; right?: ReactNode; children: ReactNode; style?: React.CSSProperties }) {
  return (
    <section className="card" style={style}>
      {(title || right) && (
        <div className="card-head">
          {title && <h2>{title}</h2>}
          {hint && <span className="hint">{hint}</span>}
          {right && <div className="right">{right}</div>}
        </div>
      )}
      {children}
    </section>
  );
}

export function Stat({ label, value, sub, tone, icon }: { label: string; value: ReactNode; sub?: ReactNode; tone?: 'good' | 'warn' | 'bad'; icon?: string }) {
  return (
    <div className={`card stat ${tone ?? ''}`}>
      {icon && <span className="icon-chip"><Icon name={icon} /></span>}
      <div className="label">{label}</div>
      <div className="value">{value}</div>
      {sub && <div className="sub">{sub}</div>}
    </div>
  );
}

export function Pill({ children, tone }: { children: ReactNode; tone?: 'good' | 'warn' | 'bad' }) {
  return <span className={`pill ${tone ?? ''}`}>{children}</span>;
}

export function Bars({ values, labels, format, color }: { values: number[]; labels: string[]; format: (v: number) => string; color?: 'red' | 'blue' }) {
  const max = Math.max(1, ...values);
  const short = (d: string) => d.slice(5).replace('-', '/');
  return (
    <>
      <div className={`bars ${color ?? ''}`} role="img" aria-label="biểu đồ cột">
        {values.map((v, i) => (
          <div key={i} className={`bar ${v === 0 ? 'zero' : ''}`} style={{ height: v === 0 ? 2 : `${(v / max) * 100}%` }} title={`${labels[i]}: ${format(v)}`} />
        ))}
      </div>
      <div className="axis">
        <span>{short(labels[0])}</span>
        <span>{short(labels[Math.floor(labels.length / 2)])}</span>
        <span>{short(labels[labels.length - 1])}</span>
      </div>
    </>
  );
}

export function HBars({ rows, format }: { rows: [string, number][]; format: (v: number) => string }) {
  const max = Math.max(1, ...rows.map((r) => r[1]));
  if (rows.length === 0) return <div className="empty">Chưa có dữ liệu.</div>;
  return (
    <div>
      {rows.map(([name, v]) => (
        <div className="hbar" key={name}>
          <span className="ellipsis" title={name}>{name}</span>
          <div className="track"><div className="fill" style={{ width: `${(v / max) * 100}%` }} /></div>
          <span className="num">{format(v)}</span>
        </div>
      ))}
    </div>
  );
}

export function Seg<T extends string | number>({ value, options, onChange }: { value: T; options: [T, string][]; onChange: (v: T) => void }) {
  return (
    <div className="seg" role="tablist">
      {options.map(([v, label]) => (
        <button key={String(v)} className={v === value ? 'on' : ''} onClick={() => onChange(v)} role="tab" aria-selected={v === value}>{label}</button>
      ))}
    </div>
  );
}

export function Avatar({ name, photo }: { name: string; photo?: string | null }) {
  return <span className="avatar">{photo ? <img src={photo} alt="" referrerPolicy="no-referrer" /> : (name.trim()[0] ?? '?').toUpperCase()}</span>;
}

/** Small modal used instead of window.prompt/confirm. */
export function Dialog({ title, message, input, inputLabel, required, confirm, danger, onClose, onConfirm }: {
  title: string; message?: ReactNode; input?: boolean; inputLabel?: string; required?: boolean; confirm: string; danger?: boolean;
  onClose: () => void; onConfirm: (text: string) => Promise<void> | void;
}) {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [onClose]);
  const submit = async () => {
    setBusy(true);
    setError(null);
    try {
      await onConfirm(text.trim());
      onClose();
    } catch (e) {
      setError(friendlyError(e));
      setBusy(false);
    }
  };
  return (
    <div className="backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="dialog" role="dialog" aria-modal>
        <h3>{title}</h3>
        {message && <p>{message}</p>}
        {input && (
          <textarea className="input" style={{ width: '100%' }} rows={3} autoFocus placeholder={inputLabel} value={text} onChange={(e) => setText(e.target.value)} />
        )}
        {error && <div className="error">{error}</div>}
        <div className="row">
          <button className="btn" onClick={onClose}>Hủy</button>
          <button className={`btn ${danger ? 'danger' : 'primary'}`} disabled={busy || (required && !text.trim())} onClick={submit}>{busy ? 'Đang lưu…' : confirm}</button>
        </div>
      </div>
    </div>
  );
}

export function syncTone(state: string): 'good' | 'warn' | 'bad' | undefined {
  return state === 'done' ? 'good' : state === 'failed' ? 'bad' : state === 'running' || state === 'pending' ? 'warn' : undefined;
}

export const syncStateText: Record<string, string> = { done: 'Xong', failed: 'Lỗi', running: 'Đang chạy', pending: 'Đang chờ' };
export const triggerText: Record<string, string> = { manual_refresh: 'Làm mới thủ công', screen_open: 'Mở màn hình', ai_review: 'AI review' };

export function providerName(p: string): string {
  return ({ codex: 'Codex', claude_code: 'Claude Code', antigravity: 'Gemini', openai: 'OpenAI', anthropic: 'Anthropic', google: 'Google' } as Record<string, string>)[p] ?? p;
}
