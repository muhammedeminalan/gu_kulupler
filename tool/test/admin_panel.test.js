'use strict';
// Yerel admin paneli (tool/admin/panel.js) — beyaz liste, argüman kurucu, sunucu korumaları (sahte koşucu;
// firebase-admin yüklenmez, betik çalıştırılmaz).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { RESERVED, SCRIPTS, buildArgs, confirmOk } = require('../admin/lib/panel_spec');
const { createPanelServer } = require('../admin/panel');

const ADMIN = path.join(__dirname, '..', 'admin');

test('panel_spec · buildArgs: izinli değer / bayrak, kırpma, boş değer atlanır, apply → --yes', () => {
  assert.deepEqual(buildArgs('push', { values: { '--title': ' GÜ ', '--body': 'Merhaba', '--email': '' }, flags: ['--all'] }, false), {
    file: 'send_push.js',
    args: ['--title', 'GÜ', '--body', 'Merhaba', '--all'],
  });
  assert.deepEqual(buildArgs('superadmin', { values: { '--email': 'a@gmail.com' } }, true).args, ['--email', 'a@gmail.com', '--yes']);
  assert.deepEqual(buildArgs('demo', {}, false), { file: 'seed_demo_content.js', args: [] });
});

test('panel_spec · buildArgs: bilinmeyen betik, panelin argümanları, izinsiz bayrak, çok satır ve - ile başlayan değer reddedilir', () => {
  assert.throws(() => buildArgs('rm', {}, false), /bilinmeyen betik/);
  assert.throws(() => buildArgs('__proto__', {}, false), /bilinmeyen betik/);
  for (const reserved of ['--key', '--project']) {
    assert.throws(() => buildArgs('push', { values: { [reserved]: 'x' } }, false), /izinsiz argüman/);
  }
  for (const reserved of ['--emulator', '--yes']) {
    assert.throws(() => buildArgs('push', { flags: [reserved] }, false), /izinsiz bayrak/);
  }
  assert.throws(() => buildArgs('push', { flags: ['--revoke'] }, false), /izinsiz bayrak/);
  assert.throws(() => buildArgs('push', { values: { '--body': 'a\nb' } }, false), /tek satır/);
  assert.throws(() => buildArgs('push', { values: { '--email': '--all' } }, false), /'-' ile/);
  assert.equal(confirmOk(' gu-kulupler ', 'gu-kulupler'), true);
  assert.equal(confirmOk('gu-kulupler-x', 'gu-kulupler'), false);
});

test('panel_spec · beyaz liste betiklerin kendi argümanlarıyla aynı (parite)', () => {
  const list = (src) => (src.match(/'(--[a-z-]+)'/g) || []).map((s) => s.slice(1, -1));
  for (const [id, script] of Object.entries(SCRIPTS)) {
    const source = fs.readFileSync(path.join(ADMIN, script.file), 'utf8');
    const spec = source.match(/const SPEC = \{ values: \[([^\]]*)\], flags: \[([^\]]*)\] \}/);
    if (spec) {
      const omitted = script.omitted || [];
      assert.deepEqual(script.values, list(spec[1]).filter((f) => !RESERVED.includes(f) && !omitted.includes(f)), `${id} values`);
      assert.deepEqual(script.flags, list(spec[2]).filter((f) => !RESERVED.includes(f)), `${id} flags`);
    } else {
      // set_superadmin.js kendi argüman okuyucusunu kullanır (has / val).
      for (const flag of script.values) assert.match(source, new RegExp(`val\\('${flag}'\\)`), `${id} ${flag}`);
      for (const flag of script.flags) assert.match(source, new RegExp(`has\\('${flag}'\\)`), `${id} ${flag}`);
    }
  }
});

/** Sunucuya istek: [headers] Host / Origin / panel başlığını ezebilir. */
function request(port, method, urlPath, { headers = {}, body } = {}) {
  return new Promise((resolve, reject) => {
    const payload = body === undefined ? undefined : JSON.stringify(body);
    const req = http.request({
      host: '127.0.0.1',
      port,
      method,
      path: urlPath,
      headers: {
        host: `127.0.0.1:${port}`,
        'x-gu-panel': '1',
        ...(payload ? { 'content-type': 'application/json' } : {}),
        ...headers,
      },
    }, (res) => {
      let data = '';
      res.on('data', (c) => { data += c; });
      res.on('end', () => {
        let json = null;
        try { json = JSON.parse(data); } catch (e) { /* HTML */ }
        resolve({ status: res.statusCode, headers: res.headers, text: data, json });
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function startServer(run) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const port = 40000 + Math.floor(Math.random() * 20000);
    const calls = [];
    const server = createPanelServer({
      projectId: 'gu-kulupler',
      keyPath: '/secrets/sa.json',
      port,
      run: (file, args, env) => {
        calls.push({ file, args, env });
        return run ? run(file, args, env) : Promise.resolve({ code: 0, output: 'tamam' });
      },
    });
    const ok = await new Promise((resolve) => {
      server.once('error', () => resolve(false));
      server.listen(port, '127.0.0.1', () => resolve(true));
    });
    if (ok) return { server, port, calls };
  }
  throw new Error('boş port bulunamadı');
}

test('panel · sağlık, sayfa (CSP nonce), Host / köken / panel başlığı korumaları', async () => {
  const { server, port } = await startServer();
  try {
    assert.equal((await request(port, 'GET', '/health')).status, 200);
    const page = await request(port, 'GET', '/');
    assert.equal(page.status, 200);
    assert.doesNotMatch(page.text, /__NONCE__/);
    assert.match(page.headers['content-security-policy'], /script-src 'nonce-/);
    assert.equal((await request(port, 'GET', '/health', { headers: { host: 'evil.example:80' } })).status, 403, 'DNS yeniden bağlama');
    assert.equal((await request(port, 'GET', '/api/info', { headers: { 'x-gu-panel': '' } })).status, 403);
    assert.equal((await request(port, 'POST', '/api/run', { headers: { origin: 'https://evil.example' }, body: { id: 'demo' } })).status, 403);
    const info = await request(port, 'GET', '/api/info');
    assert.equal(info.json.projectId, 'gu-kulupler');
    assert.equal(info.json.keyFile, 'sa.json');
    assert.deepEqual(Object.keys(info.json.scripts), Object.keys(SCRIPTS));
  } finally {
    server.close();
  }
});

test('panel · önizleme onaysız ve --yes\'siz; uygula --yes + panel onayı (proje kimliği) + anahtar yolu verir', async () => {
  const { server, port, calls } = await startServer();
  const previous = process.env.GU_ADMIN_PANEL_CONFIRM;
  process.env.GU_ADMIN_PANEL_CONFIRM = 'sızan-değer';
  try {
    const dry = await request(port, 'POST', '/api/run', { body: { id: 'push', values: { '--title': 'T', '--body': 'B' }, flags: ['--all'] } });
    assert.equal(dry.status, 200);
    assert.equal(dry.json.apply, false);
    assert.equal(calls[0].file, 'send_push.js');
    assert.ok(!calls[0].args.includes('--yes'));
    assert.equal(calls[0].env.GU_ADMIN_PANEL_CONFIRM, undefined, 'önizlemede panel onayı yok');
    assert.equal(calls[0].env.GOOGLE_APPLICATION_CREDENTIALS, '/secrets/sa.json');

    const applied = await request(port, 'POST', '/api/run', { body: { id: 'push', values: { '--title': 'T', '--body': 'B' }, flags: ['--all'], apply: true } });
    assert.equal(applied.json.apply, true);
    assert.equal(calls[1].args.at(-1), '--yes');
    assert.equal(calls[1].env.GU_ADMIN_PANEL_CONFIRM, 'gu-kulupler');

    const bad = await request(port, 'POST', '/api/run', { body: { id: 'push', values: { '--key': '/tmp/x.json' } } });
    assert.equal(bad.status, 400);
    assert.equal(calls.length, 2, 'geçersiz istek betiği çalıştırmaz');
    assert.equal((await request(port, 'POST', '/api/run', { headers: { 'content-type': 'text/plain' }, body: { id: 'demo' } })).status, 415);
  } finally {
    if (previous === undefined) delete process.env.GU_ADMIN_PANEL_CONFIRM;
    else process.env.GU_ADMIN_PANEL_CONFIRM = previous;
    server.close();
  }
});

test('panel · aynı anda tek işlem (ikinci istek 409)', async () => {
  let release;
  const gate = new Promise((resolve) => { release = resolve; });
  const { server, port } = await startServer(() => gate.then(() => ({ code: 0, output: '' })));
  try {
    const first = request(port, 'POST', '/api/run', { body: { id: 'demo' } });
    await new Promise((resolve) => setTimeout(resolve, 50));
    assert.equal((await request(port, 'POST', '/api/run', { body: { id: 'demo' } })).status, 409);
    release();
    assert.equal((await first).status, 200);
  } finally {
    server.close();
  }
});
