'use strict';
// seed_demo_content.js saf yardımcıları (firebase-admin yüklenmez).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { BATCH_MAX_WRITES } = require('../admin/lib/admin_cli');
const { EXCLUDED, buildDemoContent, toBatches } = require('../admin/lib/demo_content');

const SEED = path.join(__dirname, '..', 'seed');
const read = (file) => JSON.parse(fs.readFileSync(path.join(SEED, file), 'utf8'));
const plan = buildDemoContent(
  { data: read('demo-data.json'), extraNotifications: read('demo-notifications.json'), management: read('demo-management.json') },
  { now: new Date('2026-10-17T09:00:00Z'), randomHex: () => '0123456789abcdef' },
);

test('buildDemoContent: bildirim ve şikayet yazılmaz (Functions push tetiklerdi)', () => {
  assert.deepEqual(EXCLUDED, ['notifications', 'reports']);
  assert.ok(plan.writes.every((w) => !EXCLUDED.includes(w.path.split('/')[0])));
});

test('buildDemoContent: kulüp, üyelik, gönderi, etkinlik ve profiller var; yazımlar set', () => {
  for (const key of ['clubs/*', 'memberships/*', 'posts/*', 'comments/*', 'events/*', 'rsvps/*', 'users/*', 'users/*/private/*']) {
    assert.ok(plan.counts[key] > 0, key);
  }
  assert.equal(plan.clubIds.length, plan.counts['clubs/*']);
  assert.ok(plan.writes.every((w) => w.op === 'set'));
  assert.equal(new Set(plan.writes.map((w) => w.path)).size, plan.writes.length, 'yinelenen yol yok');
});

test('buildDemoContent: görseller kulüp ve yükleyen üst verisini taşır', () => {
  assert.ok(plan.images.length > 0);
  for (const image of plan.images) {
    assert.ok(image.path && image.clubId && image.uploaderId, image.path);
    assert.ok(image.width > 0 && image.height > 0);
  }
});

test('toBatches: sınırı aşmaz, sırayı ve tüm yazımları korur', () => {
  const batches = toBatches(plan.writes);
  assert.ok(batches.every((b) => b.length <= BATCH_MAX_WRITES));
  assert.deepEqual(batches.flat(), plan.writes);
});
