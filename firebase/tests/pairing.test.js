import { test, before, after } from 'node:test';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';
import { createMockUserToken } from '@firebase/util';
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-utoken-pairing', firestore: { rules: readFileSync('firestore.rules', 'utf8') } });
});
after(async () => env?.cleanup());
const pending = () => ({ schemaVersion: 2, state: 'pending', code: 'AB2CD3', connectionId: randomUUID(),
  mobileName: 'Android phone', desktopName: '', desktopId: '', createdAt: serverTimestamp(),
  pairedAt: null, revokedAt: null, cancelledAt: null });
const db = uid => env.authenticatedContext(uid).firestore();
const ref = uid => doc(db(uid), `users/${uid}/pairing/current`);
async function confirm(uid, changes = {}) {
  const database = db(uid), r = doc(database, `users/${uid}/pairing/current`);
  const existing = (await getDoc(r)).data();
  const data = { ...existing, state: 'paired', desktopName: 'Windows PC', desktopId: 'a'.repeat(32), pairedAt: serverTimestamp(), ...changes };
  const batch = writeBatch(database);
  batch.set(r, data); batch.set(doc(database, `users/${uid}/connections/${data.connectionId}`), data);
  return batch.commit();
}
async function revoke(uid) {
  const database = db(uid), r = doc(database, `users/${uid}/pairing/current`);
  const data = { ...(await getDoc(r)).data(), state: 'revoked', revokedAt: serverTimestamp() };
  const batch = writeBatch(database);
  batch.set(r, data); batch.set(doc(database, `users/${uid}/connections/${data.connectionId}`), data);
  return batch.commit();
}

test('owner pairs atomically, revokes, retains history and creates a new connection', async () => {
  const uid = 'lifecycle', r = ref(uid);
  await assertSucceeds(setDoc(r, pending()));
  const id = (await getDoc(r)).data().connectionId;
  await assertSucceeds(confirm(uid));
  await assertFails(confirm(uid));
  await assertFails(setDoc(r, pending()));
  await assertFails(deleteDoc(r));
  await assertSucceeds(revoke(uid));
  assert.equal((await getDoc(doc(db(uid), `users/${uid}/connections/${id}`))).data().state, 'revoked');
  await assertSucceeds(setDoc(r, pending()));
  assert.notEqual((await getDoc(r)).data().connectionId, id);
  await assertFails(deleteDoc(doc(db(uid), `users/${uid}/connections/${id}`)));
  await assertFails(setDoc(r, { ...pending(), connectionId: id }));
});
test('other accounts and anonymous clients cannot access current pairing or history', async () => {
  const uid = 'private-owner', r = ref(uid);
  await setDoc(r, pending()); await confirm(uid);
  const id = (await getDoc(r)).data().connectionId;
  for (const database of [db('intruder'), env.unauthenticatedContext().firestore()]) {
    const target = doc(database, r.path);
    await assertFails(getDoc(target)); await assertFails(setDoc(target, pending()));
    await assertFails(updateDoc(target, { state: 'revoked' })); await assertFails(deleteDoc(target));
    await assertFails(getDocs(collection(database, `users/${uid}/connections`)));
    await assertFails(getDoc(doc(database, `users/${uid}/connections/${id}`)));
  }
});
test('schema validates alphabet, UUID, server time and exact fields', async () => {
  const r = ref('validation');
  for (const code of ['123456', 'ABC0DE', 'ABO2CD', 'ABI2CD', 'AB1CDE', 'abcdef'])
    await assertFails(setDoc(r, { ...pending(), code }));
  await assertFails(setDoc(r, { ...pending(), state: 'paired' }));
  await assertFails(setDoc(r, { ...pending(), connectionId: 'not-a-uuid' }));
  await assertFails(setDoc(r, { ...pending(), createdAt: Timestamp.fromMillis(0) }));
  await assertFails(setDoc(r, { ...pending(), unexpected: true }));
  await assertFails(setDoc(r, { ...pending(), expiresAt: Timestamp.fromMillis(Date.now() + 7200000) }));
});
test('expiry is checked against server-created time; renewal is allowed', async () => {
  const uid = 'expired', r = ref(uid);
  await env.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), r.path), { ...pending(), createdAt: Timestamp.fromMillis(0) }));
  await assertFails(confirm(uid));
  await assertSucceeds(setDoc(r, pending())); await assertSucceeds(confirm(uid));
});
test('confirmation cannot change code, mobile identity or fake the paired timestamp', async () => {
  const uid = 'immutable'; await setDoc(ref(uid), pending());
  await assertFails(confirm(uid, { code: 'ZZ2ZZ3' }));
  await assertFails(confirm(uid, { mobileName: 'Other phone' }));
  await assertFails(confirm(uid, { pairedAt: Timestamp.fromMillis(0) }));
});
test('pairing and history cannot be changed independently', async () => {
  const uid = 'atomic', r = ref(uid); await setDoc(r, pending());
  await assertFails(updateDoc(r, { state: 'paired', desktopName: 'PC', desktopId: 'a'.repeat(32), pairedAt: serverTimestamp() }));
  await confirm(uid);
  await assertFails(updateDoc(r, { state: 'revoked', revokedAt: serverTimestamp() }));
});
test('cancelled pending request cannot be confirmed and can be replaced', async () => {
  const uid = 'cancelled', r = ref(uid); await setDoc(r, pending());
  await assertSucceeds(updateDoc(r, { state: 'cancelled', cancelledAt: serverTimestamp() }));
  await assertFails(confirm(uid));
  await assertSucceeds(setDoc(r, pending()));
});
test('only one concurrent confirmation succeeds', async () => {
  const uid = 'race'; await setDoc(ref(uid), pending());
  const result = await Promise.allSettled([confirm(uid), confirm(uid)]);
  assert.equal(result.filter(x => x.status === 'fulfilled').length, 1);
});
test('desktop REST commit shape is accepted; stale replay is rejected', async () => {
  const uid = 'rest'; await setDoc(ref(uid), pending());
  const host = process.env.FIRESTORE_EMULATOR_HOST; assert.ok(host);
  const project = 'demo-utoken-pairing';
  const base = `projects/${project}/databases/(default)/documents`;
  const name = `${base}/users/${uid}/pairing/current`;
  const headers = { Authorization: `Bearer ${createMockUserToken({ sub: uid }, project)}`, 'Content-Type': 'application/json' };
  const original = await fetch(`http://${host}/v1/${name}`, { headers }); assert.equal(original.status, 200);
  const document = await original.json();
  const fields = { ...document.fields, state: { stringValue: 'paired' }, desktopName: { stringValue: 'Windows PC' }, desktopId: { stringValue: 'a'.repeat(32) } };
  const updateTransforms = [{ fieldPath: 'pairedAt', setToServerValue: 'REQUEST_TIME' }];
  const body = JSON.stringify({ writes: [
    { update: { name, fields }, updateTransforms, currentDocument: { updateTime: document.updateTime } },
    { update: { name: `${base}/users/${uid}/connections/${fields.connectionId.stringValue}`, fields }, updateTransforms, currentDocument: { exists: false } }
  ] });
  const endpoint = `http://${host}/v1/${base}:commit`;
  const response = await fetch(endpoint, { method: 'POST', headers, body });
  assert.equal(response.status, 200, await response.text());
  assert.equal((await getDoc(ref(uid))).data().state, 'paired');
  assert.notEqual((await fetch(endpoint, { method: 'POST', headers, body })).status, 200);
});