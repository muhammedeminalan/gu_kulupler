'use strict';
// create_review_account.js saf yardımcıları (firebase-admin yüklenmez).
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { REPO } = require('../admin/lib/admin_cli');
const { readEmailDomains } = require('../lib/dart_sources');
const { PASSWORD_PATTERN, generatePassword, planAccount, validateEmail } = require('../admin/lib/review_account');

const DOMAINS = readEmailDomains(REPO);

test('validateEmail: izinli alan adı (Dart listesinden), kırpar; + takma adı geçer', () => {
  assert.equal(validateEmail('  ayse@ogr.gumushane.edu.tr ', DOMAINS), 'ayse@ogr.gumushane.edu.tr');
  assert.equal(validateEmail('a@GUMUSHANE.EDU.TR', DOMAINS), 'a@GUMUSHANE.EDU.TR');
  if (DOMAINS.includes('gmail.com')) assert.equal(validateEmail('kisi+review@gmail.com', DOMAINS), 'kisi+review@gmail.com');
});

test('validateEmail: boş, bozuk ve izinsiz alan adını reddeder', () => {
  assert.throws(() => validateEmail('', DOMAINS), /boş/);
  assert.throws(() => validateEmail(null, DOMAINS), /boş/);
  for (const bad of ['ayse', '@gmail.com', 'ayse@', 'a@b@gmail.com', 'a b@gmail.com']) {
    assert.throws(() => validateEmail(bad, DOMAINS), /geçersiz/, bad);
  }
  for (const bad of ['a@x.gumushane.edu.tr', 'a@evilgumushane.edu.tr', 'a@gumushane.edu.tr.evil.com', 'a@outlook.com']) {
    assert.throws(() => validateEmail(bad, DOMAINS), /izinli değil/, bad);
  }
});

test('generatePassword: uygulama kuralına uyar, 19 karakter, karışan karakter yok, her seferinde farklı', () => {
  const seen = new Set();
  for (let i = 0; i < 200; i += 1) {
    const password = generatePassword(crypto.randomBytes);
    assert.match(password, PASSWORD_PATTERN);
    assert.match(password, /^[A-Z][a-z2-9]{3}(-[a-z2-9]{4}){2}-[a-z2-9]{3}[2-9]$/);
    assert.doesNotMatch(password, /[01lIO]/);
    seen.add(password);
  }
  assert.equal(seen.size, 200);
});

test('generatePassword: tümü sıfır baytla bile kurala uyar', () => {
  assert.match(generatePassword((n) => Buffer.alloc(n)), PASSWORD_PATTERN);
});

test('planAccount: yoksa aç; varsa yalnızca eksik olanı yap', () => {
  assert.deepEqual(planAccount(null, { resetPassword: false }), { action: 'create', verify: true, resetPassword: true });
  assert.deepEqual(planAccount({ emailVerified: true, disabled: false }, { resetPassword: false }), { action: 'none', verify: false, resetPassword: false });
  assert.deepEqual(planAccount({ emailVerified: false, disabled: false }, { resetPassword: false }), { action: 'update', verify: true, resetPassword: false });
  assert.deepEqual(planAccount({ emailVerified: false, disabled: false }, { resetPassword: true }), { action: 'update', verify: true, resetPassword: true });
  assert.deepEqual(planAccount({ emailVerified: true, disabled: false }, { resetPassword: true }), { action: 'update', verify: false, resetPassword: true });
  assert.equal(planAccount({ emailVerified: false, disabled: true }, { resetPassword: true }).action, 'blocked', 'askıdaki hesaba dokunulmaz');
});
