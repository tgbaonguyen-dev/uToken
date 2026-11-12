import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

test('collector binding uses atomic exists/updateTime preconditions', async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host, 'Run only inside the Firestore emulator');
  assert.match(host, /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/);
  const base = `http://${host}/v1/projects/demo-utoken/databases/(default)/documents`;
  const name = `projects/demo-utoken/databases/(default)/documents/users/collector-test-${randomUUID()}`;
  const claim = (id, currentDocument) => fetch(`${base}:commit`, {
    method: 'POST',
    // Emulator admin credential only: this checks the REST precondition contract, not Rules isolation.
    headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes: [{
      update: { name, fields: { collector_id: { stringValue: id } } },
      updateMask: { fieldPaths: ['collector_id'] }, currentDocument,
    }] }),
  });
  try {
    const results = await Promise.all([claim('desktop-a', { exists: false }), claim('desktop-b', { exists: false })]);
    assert.equal(results.filter(r => r.ok).length, 1);
    const read = await fetch(`${base}/${name.split('/documents/')[1]}`, { headers: { Authorization: 'Bearer owner' } });
    assert.equal(read.status, 200);
    const saved = await read.json();
    assert.ok(['desktop-a', 'desktop-b'].includes(saved.fields.collector_id.stringValue));
    assert.ok((await claim('test-renewal', { updateTime: saved.updateTime })).ok);
    const stale = await claim('different-desktop', { updateTime: saved.updateTime });
    assert.equal(stale.ok, false);
  } finally {
    await fetch(`${base}/${name.split('/documents/')[1]}`, { method: 'DELETE', headers: { Authorization: 'Bearer owner' } });
  }
});
