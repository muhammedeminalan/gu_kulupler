'use strict';
// send_push.js saf yardımcıları (firebase-admin yüklenmez).
const test = require('node:test');
const assert = require('node:assert/strict');
const { BODY_MAX, MULTICAST_MAX, TITLE_MAX, buildMulticasts, collectTokens, validateText } = require('../admin/lib/push_broadcast');

test('validateText: kırpar, boş ve uzun metni reddeder', () => {
  assert.deepEqual(validateText('  GÜ Kulüpler ', ' Merhaba '), { title: 'GÜ Kulüpler', body: 'Merhaba' });
  assert.throws(() => validateText('', 'x'), /--title/);
  assert.throws(() => validateText('x', '   '), /--body/);
  assert.throws(() => validateText('a'.repeat(TITLE_MAX + 1), 'x'), /en çok/);
  assert.throws(() => validateText('x', 'a'.repeat(BODY_MAX + 1)), /en çok/);
});

test('collectTokens: benzersiz, boş olmayan jetonlar; bozuk kayıtlar atlanır', () => {
  const tokens = collectTokens([
    { fcmTokens: [{ token: 'a', platform: 'ios' }, { token: 'b' }, { token: ' ' }, null] },
    { fcmTokens: [{ token: 'a' }] },
    {},
    null,
    { fcmTokens: 'bozuk' },
  ]);
  assert.deepEqual(tokens, ['a', 'b']);
});

test('buildMulticasts: 500 jetonluk parçalar; Android kanal / ikon / renk, iOS ses', () => {
  const tokens = Array.from({ length: MULTICAST_MAX + 1 }, (_, i) => `t${i}`);
  const chunks = buildMulticasts({ title: 'T', body: 'B', tokens });
  assert.equal(chunks.length, 2);
  assert.equal(chunks[0].tokens.length, MULTICAST_MAX);
  assert.equal(chunks[1].tokens.length, 1);
  assert.deepEqual(chunks[0].notification, { title: 'T', body: 'B' });
  assert.equal(chunks[0].android.notification.channelId, 'gu_push');
  assert.equal(chunks[0].android.notification.icon, 'ic_stat_notification');
  assert.equal(chunks[0].apns.payload.aps.sound, 'default');
});
