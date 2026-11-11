import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, onSnapshot } from 'firebase/firestore';

test('console-style admin edits reach an authenticated live listener', async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-utoken', firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
  const uid = `console-test-${randomUUID()}`;
  const path = `users/${uid}/daily/2026-11-10`;
  let current;
  let pending;
  let listenerError;
  const stop = onSnapshot(doc(env.authenticatedContext(uid).firestore(), path), snapshot => {
    current = snapshot.exists() ? snapshot.data() : null;
    pending?.();
  }, error => { listenerError = error; pending?.(); });
  const waitFor = predicate => new Promise((resolve, reject) => {
    const timeout = setTimeout(() => { pending = undefined; reject(new Error('Listener did not receive console edit')); }, 10000);
    const check = () => {
      if (!listenerError && !predicate(current)) return;
      clearTimeout(timeout); pending = undefined;
      listenerError ? reject(listenerError) : resolve();
    };
    pending = check; check();
  });
  try {
    // Console administrative writes bypass client rules; no production project is used.
    await env.withSecurityRulesDisabled(async context => {
      const target = doc(context.firestore(), path);
      await setDoc(target, { schema_version: 2, date: '2026-11-10', totals: { input: 100, output: 20 } });
      await waitFor(value => value?.totals.input === 100);
      await updateDoc(target, { 'totals.input': 200 });
      await waitFor(value => value?.totals.input === 200);
      assert.equal(current.totals.input + current.totals.output, 220);
      await updateDoc(target, { 'totals.input': 'wrong string' });
      await waitFor(value => value?.totals.input === 'wrong string');
      await updateDoc(target, { 'totals.input': 300 });
      await waitFor(value => value?.totals.input === 300);
      await deleteDoc(target);
      await waitFor(value => value === null);
    });
  } finally { stop(); await env.cleanup(); }
});
