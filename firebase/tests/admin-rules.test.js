import { test, before, after } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, collectionGroup, getDocs } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-utoken',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'admins/root'), { email: 'root@example.com' });
    await setDoc(doc(db, 'users/carol'), { email: 'carol@example.com' });
    await setDoc(doc(db, 'users/carol/crash_reports/c1'), { type: 'test_crash', message: 'x' });
    await setDoc(doc(db, 'users/carol/daily/2026-11-10'), { schema_version: 2 });
  });
});
after(async () => env.cleanup());

const admin = () => env.authenticatedContext('root').firestore();
const user = (uid) => env.authenticatedContext(uid).firestore();

test('admin đọc được dữ liệu mọi user, kể cả collection group', async () => {
  await assertSucceeds(getDoc(doc(admin(), 'users/carol')));
  await assertSucceeds(getDoc(doc(admin(), 'users/carol/daily/2026-11-10')));
  await assertSucceeds(getDocs(collectionGroup(admin(), 'crash_reports')));
  await assertSucceeds(getDocs(collectionGroup(admin(), 'daily')));
});

test('user thường không đọc được collection group hay dữ liệu admin', async () => {
  await assertFails(getDocs(collectionGroup(user('dave'), 'crash_reports')));
  await assertFails(getDoc(doc(user('dave'), 'admins/root')));
  await assertFails(getDocs(collection(user('dave'), 'admin_audit')));
});

test('admin không sửa được usage của user', async () => {
  await assertFails(setDoc(doc(admin(), 'users/carol/daily/2026-11-10'), { schema_version: 2 }));
  await assertFails(setDoc(doc(admin(), 'users/carol'), { email: 'hack' }));
});

test('admin chỉ đổi trạng thái xử lý của crash report', async () => {
  const ref = doc(admin(), 'users/carol/crash_reports/c1');
  await assertSucceeds(updateDoc(ref, { status: 'resolved', resolved_by: 'root' }));
  await assertFails(updateDoc(ref, { message: 'edited' }));
});

test('không ai tự cấp quyền admin', async () => {
  await assertFails(setDoc(doc(user('dave'), 'admins/dave'), {}));
  await assertFails(setDoc(doc(admin(), 'admins/dave'), {}));
});

test('tạm khóa: admin khóa được, user bị khóa mất quyền, mở lại thì có lại', async () => {
  await assertSucceeds(getDoc(doc(user('carol'), 'users/carol')));
  await assertFails(setDoc(doc(user('dave'), 'suspended/carol'), { by_uid: 'dave', reason: 'x' }));
  await assertSucceeds(setDoc(doc(admin(), 'suspended/carol'), { by_uid: 'root', reason: 'abuse' }));
  await assertFails(getDoc(doc(user('carol'), 'users/carol')));
  await assertSucceeds(getDoc(doc(user('carol'), 'suspended/carol')));
  await assertSucceeds(deleteDoc(doc(admin(), 'suspended/carol')));
  await assertSucceeds(getDoc(doc(user('carol'), 'users/carol')));
});

test('nhật ký admin chỉ thêm, đúng người thực hiện', async () => {
  await assertSucceeds(addDoc(collection(admin(), 'admin_audit'), { actor_uid: 'root', action: 'suspend' }));
  await assertFails(addDoc(collection(admin(), 'admin_audit'), { actor_uid: 'other', action: 'suspend' }));
  await assertFails(addDoc(collection(user('dave'), 'admin_audit'), { actor_uid: 'dave', action: 'x' }));
});

const notice = (by) => ({ title: 'Bảo trì', body: 'Tối nay 22h', level: 'warning', active: true, created_by: by });

test('thông báo chung: admin tạo/tắt, user chỉ đọc', async () => {
  await assertSucceeds(setDoc(doc(admin(), 'announcements/a1'), notice('root')));
  await assertFails(setDoc(doc(admin(), 'announcements/a2'), { ...notice('root'), level: 'spam' }));
  await assertFails(setDoc(doc(admin(), 'announcements/a3'), notice('someone-else')));
  await assertFails(setDoc(doc(user('dave'), 'announcements/a4'), notice('dave')));
  await assertSucceeds(getDoc(doc(user('dave'), 'announcements/a1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'announcements/a1')));
  await assertSucceeds(updateDoc(doc(admin(), 'announcements/a1'), { active: false }));
  await assertFails(updateDoc(doc(admin(), 'announcements/a1'), { body: 'sửa nội dung' }));
  await assertFails(updateDoc(doc(user('dave'), 'announcements/a1'), { active: true }));
});

test('thông báo riêng: chỉ chủ tài khoản đọc, user không tự tạo được', async () => {
  await assertSucceeds(setDoc(doc(admin(), 'users/carol/inbox/m1'), notice('root')));
  await assertSucceeds(getDoc(doc(user('carol'), 'users/carol/inbox/m1')));
  await assertFails(getDoc(doc(user('dave'), 'users/carol/inbox/m1')));
  await assertFails(setDoc(doc(user('carol'), 'users/carol/inbox/m2'), notice('carol')));
});
