import {
  addDoc, collection, collectionGroup, deleteDoc, doc, getDoc, getDocs, limit, orderBy, query,
  serverTimestamp, setDoc, updateDoc, where, type DocumentSnapshot,
} from 'firebase/firestore';
import { auth, db } from './firebase';
import { parseTotals, toDate, type CrashRow, type DailyRow, type SyncRow, type Totals } from './stats';

export type UserRow = {
  uid: string;
  email: string | null;
  displayName: string | null;
  desktopName: string | null;
  desktopOs: string | null;
  mobileVersion: string | null;
  mobilePlatform: string | null;
  lastSeenAt: Date | null;
  lastSyncAt: Date | null;
  suspended: Suspension | null;
};

export type Suspension = { reason: string; byUid: string; at: Date | null };

export type InsightRow = {
  uid: string;
  status: string;
  score: number | null;
  grade: string | null;
  provider: string;
  model: string;
  source: string;
  generatedAt: Date | null;
  headline: string;
  insightCount: number;
  errorCode: string | null;
};

export type AuditRow = { id: string; actorUid: string; actorEmail: string; action: string; targetUid: string | null; detail: string; at: Date | null };

/** Collection-group indexes take minutes to build after deploy; until then, read unordered. */
async function withIndexFallback<T>(indexed: () => Promise<T>, plain: () => Promise<T>): Promise<T> {
  try {
    return await indexed();
  } catch (e) {
    if ((e as { code?: string }).code === 'failed-precondition') return plain();
    throw e;
  }
}

const byNewest = (a: { createdAt: Date | null }, b: { createdAt: Date | null }) =>
  (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0);

const ownerOf = (d: DocumentSnapshot) => d.ref.parent.parent?.id ?? '';
const str = (v: unknown) => (typeof v === 'string' && v.length > 0 ? v : null);

export async function isAdmin(uid: string): Promise<boolean> {
  try {
    return (await getDoc(doc(db, 'admins', uid))).exists();
  } catch {
    return false;
  }
}

export async function loadSuspensions(): Promise<Map<string, Suspension>> {
  const snap = await getDocs(collection(db, 'suspended'));
  return new Map(snap.docs.map((d) => [d.id, { reason: String(d.data().reason ?? ''), byUid: String(d.data().by_uid ?? ''), at: toDate(d.data().at) }]));
}

export async function loadUsers(): Promise<UserRow[]> {
  const [snap, suspended] = await Promise.all([getDocs(collection(db, 'users')), loadSuspensions()]);
  return snap.docs.map((d) => userFrom(d.id, d.data(), suspended.get(d.id) ?? null));
}

export async function loadUser(uid: string): Promise<UserRow | null> {
  const [snap, sus] = await Promise.all([getDoc(doc(db, 'users', uid)), getDoc(doc(db, 'suspended', uid))]);
  if (!snap.exists()) return null;
  const s = sus.exists() ? { reason: String(sus.data().reason ?? ''), byUid: String(sus.data().by_uid ?? ''), at: toDate(sus.data().at) } : null;
  return userFrom(uid, snap.data(), s);
}

function userFrom(uid: string, m: Record<string, unknown>, suspended: Suspension | null): UserRow {
  return {
    uid,
    email: str(m.email),
    displayName: str(m.display_name),
    desktopName: str(m.desktop_name),
    desktopOs: str(m.desktop_os),
    mobileVersion: str(m.mobile_app_version),
    mobilePlatform: str(m.mobile_platform),
    lastSeenAt: toDate(m.last_seen_at),
    lastSyncAt: toDate(m.last_sync_at),
    suspended,
  };
}

function dailyFrom(d: DocumentSnapshot, uid = ownerOf(d)): DailyRow {
  const m = d.data() ?? {};
  const byKey: Record<string, Totals> = {};
  for (const [k, v] of Object.entries((m.by_key ?? {}) as Record<string, unknown>)) byKey[k] = parseTotals(v);
  return { uid, date: typeof m.date === 'string' ? m.date : d.id, totals: parseTotals(m.totals), byKey };
}

/** Daily summaries of every user since `startDay` (YYYY-MM-DD). */
export async function loadDailySince(startDay: string): Promise<DailyRow[]> {
  const snap = await withIndexFallback(
    () => getDocs(query(collectionGroup(db, 'daily'), where('date', '>=', startDay))),
    () => getDocs(collectionGroup(db, 'daily')),
  );
  return snap.docs.map((d) => dailyFrom(d)).filter((r) => r.date >= startDay);
}

export async function loadUserDaily(uid: string, startDay: string): Promise<DailyRow[]> {
  const snap = await getDocs(query(collection(db, 'users', uid, 'daily'), where('date', '>=', startDay)));
  return snap.docs.map((d) => dailyFrom(d, uid)).sort((a, b) => a.date.localeCompare(b.date));
}

function syncFrom(d: DocumentSnapshot, uid = ownerOf(d)): SyncRow {
  const m = d.data() ?? {};
  return {
    uid,
    id: d.id,
    trigger: String(m.trigger ?? ''),
    state: String(m.state ?? ''),
    errorCode: str(m.error_code),
    createdAt: toDate(m.created_at),
    startedAt: toDate(m.started_at),
    finishedAt: toDate(m.finished_at),
  };
}

export async function loadSyncRequests(max = 500): Promise<SyncRow[]> {
  const snap = await withIndexFallback(
    () => getDocs(query(collectionGroup(db, 'sync_requests'), orderBy('created_at', 'desc'), limit(max))),
    () => getDocs(collectionGroup(db, 'sync_requests')),
  );
  return snap.docs.map((d) => syncFrom(d)).sort(byNewest).slice(0, max);
}

export async function loadUserSyncRequests(uid: string, max = 30): Promise<SyncRow[]> {
  const snap = await getDocs(query(collection(db, 'users', uid, 'sync_requests'), orderBy('created_at', 'desc'), limit(max)));
  return snap.docs.map((d) => syncFrom(d, uid));
}

function crashFrom(d: DocumentSnapshot, uid = ownerOf(d)): CrashRow {
  const m = d.data() ?? {};
  return {
    uid,
    id: d.id,
    type: String(m.type ?? 'crash'),
    message: String(m.message ?? ''),
    platform: String(m.platform ?? ''),
    appVersion: String(m.app_version ?? ''),
    screen: String(m.screen ?? ''),
    createdAt: toDate(m.created_at) ?? toDate(m.client_time),
    status: m.status === 'resolved' ? 'resolved' : 'open',
    adminNote: String(m.admin_note ?? ''),
    stack: String(m.stack ?? ''),
    resolvedAt: toDate(m.resolved_at),
  };
}

export async function loadCrashes(max = 500): Promise<CrashRow[]> {
  const snap = await withIndexFallback(
    () => getDocs(query(collectionGroup(db, 'crash_reports'), orderBy('created_at', 'desc'), limit(max))),
    () => getDocs(collectionGroup(db, 'crash_reports')),
  );
  return snap.docs.map((d) => crashFrom(d)).sort(byNewest);
}

export async function loadUserCrashes(uid: string): Promise<CrashRow[]> {
  const snap = await getDocs(query(collection(db, 'users', uid, 'crash_reports'), orderBy('created_at', 'desc'), limit(50)));
  return snap.docs.map((d) => crashFrom(d, uid));
}

function insightFrom(d: DocumentSnapshot, uid = ownerOf(d)): InsightRow {
  const m = d.data() ?? {};
  return {
    uid,
    status: String(m.status ?? ''),
    score: typeof m.score === 'number' ? m.score : null,
    grade: str(m.grade),
    provider: String(m.provider ?? ''),
    model: String(m.model ?? ''),
    source: m.source === 'phone' ? 'phone' : 'desktop',
    generatedAt: toDate(m.generated_at),
    headline: String(m.headline ?? ''),
    insightCount: Array.isArray(m.insights) ? m.insights.length : 0,
    errorCode: str(m.error_code),
  };
}

export async function loadInsights(): Promise<InsightRow[]> {
  const snap = await getDocs(collectionGroup(db, 'insights'));
  return snap.docs.filter((d) => d.id === 'current').map((d) => insightFrom(d));
}

export async function loadUserInsight(uid: string): Promise<InsightRow | null> {
  const snap = await getDoc(doc(db, 'users', uid, 'insights', 'current'));
  return snap.exists() ? insightFrom(snap, uid) : null;
}

export async function loadAudit(max = 200): Promise<AuditRow[]> {
  const snap = await getDocs(query(collection(db, 'admin_audit'), orderBy('at', 'desc'), limit(max)));
  return snap.docs.map((d) => {
    const m = d.data();
    return { id: d.id, actorUid: String(m.actor_uid ?? ''), actorEmail: String(m.actor_email ?? ''), action: String(m.action ?? ''), targetUid: str(m.target_uid), detail: String(m.detail ?? ''), at: toDate(m.at) };
  });
}

export async function loadAdmins(): Promise<{ uid: string; email: string }[]> {
  const snap = await getDocs(collection(db, 'admins'));
  return snap.docs.map((d) => ({ uid: d.id, email: String(d.data().email ?? '') }));
}

// ── Admin actions (each one is written to admin_audit) ──

async function audit(action: string, targetUid: string | null, detail: string) {
  const me = auth.currentUser!;
  await addDoc(collection(db, 'admin_audit'), {
    actor_uid: me.uid,
    actor_email: me.email ?? '',
    action,
    target_uid: targetUid,
    detail,
    at: serverTimestamp(),
  });
}

export async function suspendUser(uid: string, reason: string) {
  await setDoc(doc(db, 'suspended', uid), { by_uid: auth.currentUser!.uid, reason, at: serverTimestamp() });
  await audit('suspend_user', uid, reason);
}

export async function unsuspendUser(uid: string) {
  await deleteDoc(doc(db, 'suspended', uid));
  await audit('unsuspend_user', uid, '');
}

export async function setCrashStatus(c: CrashRow, status: 'open' | 'resolved', note: string) {
  await updateDoc(doc(db, 'users', c.uid, 'crash_reports', c.id), {
    status,
    admin_note: note,
    resolved_by: status === 'resolved' ? auth.currentUser!.uid : null,
    resolved_at: status === 'resolved' ? serverTimestamp() : null,
  });
  await audit(status === 'resolved' ? 'resolve_crash' : 'reopen_crash', c.uid, `${c.id}${note ? ` · ${note}` : ''}`);
}
