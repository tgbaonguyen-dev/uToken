import { test, before, beforeEach, after } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-utoken',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

test('người dùng đọc được dữ liệu của mình', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'users/alice/daily/2026-11-05')));
});

test('không đọc được dữ liệu người khác', async () => {
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'users/alice/daily/2026-11-05')));
});

test('daily phải đúng schema_version', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'users/alice/daily/2026-11-05'), { schema_version: 1 }));
  await assertSucceeds(setDoc(doc(db, 'users/alice/daily/2026-11-05'), { schema_version: 2 }));
});

test('sync request chỉ nhận trigger hợp lệ', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'users/alice/sync_requests/x'), { trigger: 'cron', state: 'pending' }));
  await assertSucceeds(setDoc(doc(db, 'users/alice/sync_requests/y'), { trigger: 'manual_refresh', state: 'pending' }));
});

test('không ai ghi được bảng giá', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'pricing/v1'), { x: 1 }));
});

test('không đăng nhập thì không đọc hoặc ghi được dữ liệu người dùng', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'users/alice')));
  await assertFails(setDoc(doc(db, 'users/alice/settings/general'), { language: 'vi' }));
});

test('tài khoản khác không ghi hoặc xóa được daily', async () => {
  const owner = env.authenticatedContext('alice').firestore();
  const other = env.authenticatedContext('bob').firestore();
  const path = 'users/alice/daily/2026-11-06';
  await assertSucceeds(setDoc(doc(owner, path), { schema_version: 2 }));
  await assertFails(setDoc(doc(other, path), { schema_version: 2 }));
  await assertFails(deleteDoc(doc(other, path)));
  await assertSucceeds(deleteDoc(doc(owner, path)));
});

test('fallback không cho phép bỏ qua schema khi cập nhật daily', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const path = 'users/alice/daily/2026-11-07';
  await assertSucceeds(setDoc(doc(db, path), { schema_version: 2 }));
  await assertFails(setDoc(doc(db, path), { schema_version: 1 }));
  await assertFails(setDoc(doc(db, 'users/alice/daily/not-a-date'), { schema_version: 2 }));
});

test('sync update giữ nguyên trigger và chỉ nhận state trong contract', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const ref = doc(db, 'users/alice/sync_requests/progress');
  await assertSucceeds(setDoc(ref, { trigger: 'manual_refresh', state: 'pending' }));
  await assertFails(setDoc(ref, { trigger: 'cron', state: 'running' }));
  await assertFails(setDoc(ref, { trigger: 'manual_refresh', state: 'unknown' }));
  await assertSucceeds(setDoc(ref, { trigger: 'manual_refresh', state: 'running' }));
  await assertSucceeds(setDoc(ref, { trigger: 'manual_refresh', state: 'done' }));
});
