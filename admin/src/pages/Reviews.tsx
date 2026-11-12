import { Link } from 'react-router-dom';
import { loadInsights, loadUsers } from '../lib/data';
import { fmtAgo, fmtDateTime, pct } from '../lib/stats';
import { HBars, Loading, Page, Pill, Stat, providerName, useLoad, RefreshButton } from '../ui';

export function Reviews() {
  const state = useLoad(async () => {
    const [insights, users] = await Promise.all([loadInsights(), loadUsers()]);
    return { insights, emails: new Map(users.map((u) => [u.uid, u.email ?? u.uid])) };
  });

  return (
    <Page title="AI review" sub="Bản đánh giá hiện tại của mỗi người dùng (insights/current)" actions={<RefreshButton onClick={state.reload} loading={state.loading} />}>
      <Loading state={state}>
        {({ insights, emails }) => {
          const ok = insights.filter((i) => i.status === 'ok');
          const failed = insights.filter((i) => i.status === 'failed');
          const scores = ok.map((i) => i.score).filter((s): s is number => s !== null);
          const avg = scores.length ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length) : null;
          const grades = new Map<string, number>();
          const models = new Map<string, number>();
          const errors = new Map<string, number>();
          for (const i of ok) grades.set(i.grade ?? '—', (grades.get(i.grade ?? '—') ?? 0) + 1);
          for (const i of insights) models.set(`${providerName(i.provider)} · ${i.model}`, (models.get(`${providerName(i.provider)} · ${i.model}`) ?? 0) + 1);
          for (const i of failed) errors.set(i.errorCode ?? 'unknown', (errors.get(i.errorCode ?? 'unknown') ?? 0) + 1);
          const sorted = [...insights].sort((a, b) => (b.generatedAt?.getTime() ?? 0) - (a.generatedAt?.getTime() ?? 0));
          return (
            <>
              <div className="grid kpis">
                <Stat label="Người dùng có review" value={insights.length} />
                <Stat label="Điểm trung bình" value={avg ?? '—'} />
                <Stat label="Review lỗi" value={failed.length} tone={failed.length ? 'bad' : undefined} sub={pct(failed.length, insights.length)} />
                <Stat label="Chạy trên điện thoại" value={insights.filter((i) => i.source === 'phone').length} />
              </div>
              <div className="grid two">
                <div className="card"><div className="card-head"><h2>Phân bố hạng</h2></div><HBars rows={['A', 'B', 'C', 'D', '—'].filter((g) => grades.has(g)).map((g) => [g, grades.get(g)!])} format={String} /></div>
                <div className="card"><div className="card-head"><h2>Model đánh giá</h2></div><HBars rows={[...models.entries()].sort((a, b) => b[1] - a[1])} format={String} /></div>
                {errors.size > 0 && <div className="card"><div className="card-head"><h2>Lỗi review</h2></div><HBars rows={[...errors.entries()]} format={String} /></div>}
              </div>
              <div className="card">
                <div className="table-wrap">
                  <table>
                    <thead><tr><th>Người dùng</th><th>Lúc</th><th>Nguồn</th><th>Model</th><th className="num">Điểm</th><th>Tóm tắt</th><th>Trạng thái</th></tr></thead>
                    <tbody>
                      {sorted.map((i) => (
                        <tr key={i.uid}>
                          <td><Link to={`/users/${i.uid}`}>{emails.get(i.uid) ?? i.uid}</Link></td>
                          <td>{fmtDateTime(i.generatedAt)}<div className="muted">{fmtAgo(i.generatedAt)}</div></td>
                          <td>{i.source === 'phone' ? 'Điện thoại' : 'Desktop'}</td>
                          <td>{providerName(i.provider)}<div className="muted">{i.model}</div></td>
                          <td className="num">{i.score ?? '—'} {i.grade && <span className="muted">({i.grade})</span>}</td>
                          <td className="ellipsis" title={i.headline}>{i.headline}</td>
                          <td><Pill tone={i.status === 'ok' ? 'good' : i.status === 'failed' ? 'bad' : 'warn'}>{i.status}</Pill></td>
                        </tr>
                      ))}
                      {sorted.length === 0 && <tr><td colSpan={7} className="empty">Chưa có review.</td></tr>}
                    </tbody>
                  </table>
                </div>
              </div>
            </>
          );
        }}
      </Loading>
    </Page>
  );
}
