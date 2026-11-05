import { test, before, after } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-utoken',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());

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
