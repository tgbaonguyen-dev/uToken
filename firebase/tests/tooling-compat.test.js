import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { once } from 'node:events';
import { test } from 'node:test';

// Resolve as the CLI does; these checks protect the deliberately scoped overrides.
const require = createRequire(import.meta.url);
const cliRequire = createRequire(require.resolve('firebase-tools/package.json'));

test('patched glob retains sync/async/stream APIs used by CLI tooling', async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'utoken-glob-'));
  try {
    await mkdir(path.join(dir, 'nested'));
    await writeFile(path.join(dir, 'nested', 'usage.txt'), 'synthetic');
    const glob = cliRequire('glob');
    const options = { cwd: dir, nodir: true };
    const expected = [path.join('nested', 'usage.txt')];
    assert.deepEqual(glob.sync('**/*.txt', options), expected);
    assert.deepEqual(await glob.glob('**/*.txt', options), expected);
    const streamed = [];
    for await (const file of glob.globStream('**/*.txt', options)) streamed.push(file);
    assert.deepEqual(streamed, expected);
    // Hosting upload file lists explicitly request forward slashes on Windows.
    const { listFiles } = cliRequire('./lib/listFiles.js');
    assert.deepEqual(listFiles(dir), ['nested/usage.txt']);
    assert.equal(glob.hasMagic('**/*.txt'), true);
    const abort = new AbortController();
    abort.abort();
    await assert.rejects(glob.glob('**/*', { cwd: dir, signal: abort.signal }));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('CLI archiver still expands files through the patched glob', async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'utoken-archive-'));
  try {
    await writeFile(path.join(dir, 'usage.txt'), 'synthetic usage');
    const archive = cliRequire('archiver')('zip');
    const entries = [];
    const chunks = [];
    archive.on('entry', (entry) => entries.push(entry.name));
    archive.on('data', (chunk) => chunks.push(chunk));
    const done = once(archive, 'end');
    archive.glob('*.txt', { cwd: dir });
    await archive.finalize();
    await done;
    assert.deepEqual(entries, ['usage.txt']);
    assert.equal(Buffer.concat(chunks).subarray(0, 2).toString(), 'PK');
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('gaxios multipart still uses the patched CommonJS uuid v4 API', { timeout: 5000 }, async () => {
  let requestBody = '';
  let contentType = '';
    const { Gaxios } = cliRequire('gaxios');
    const response = await new Gaxios().request({
      url: 'http://127.0.0.1/synthetic-test',
      method: 'POST',
      multipart: [{ headers: { 'Content-Type': 'text/plain' }, content: 'synthetic multipart' }],
      retry: false,
      errorRedactor: false,
      headers: {},
      adapter: async (opts) => {
        contentType = opts.headers['Content-Type'];
        for await (const chunk of opts.body) requestBody += chunk.toString();
        return { data: { ok: true }, status: 200, statusText: 'OK', headers: {}, config: opts };
      },
    });
    assert.equal(response.data.ok, true);
    assert.match(contentType, /multipart\/related; boundary=[0-9a-f-]{36}/);
    assert.match(requestBody, /synthetic multipart/);
});

test('CLI PubSub adapter retains its local construction and close APIs', async () => {
  const { PubSub } = cliRequire('@google-cloud/pubsub');
  const client = new PubSub({ projectId: 'demo-utoken', apiEndpoint: '127.0.0.1:8085' });
  try {
    assert.equal(client.topic('qa-topic').name, 'projects/demo-utoken/topics/qa-topic');
    const subscription = client.subscription('qa-subscription');
    assert.equal(subscription.name, 'projects/demo-utoken/subscriptions/qa-subscription');
    assert.equal(typeof subscription.on, 'function');
    await subscription.close();
  } finally {
    await client.close();
  }
});
