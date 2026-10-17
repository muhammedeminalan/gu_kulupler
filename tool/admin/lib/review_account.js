'use strict';
/**
 * İnceleme hesabı (create_review_account.js) — saf yardımcılar (firebase-admin yüklemez; tool/test ile sınanır).
 *
 * Betik yalnızca Auth hesabını açar (e-posta doğrulanmış) ya da var olanı doğrular; Firestore'a yazmaz. Profil
 * belgelerini (users, private/account, settings) ilk girişte uygulamanın kendi profil kurulumu yazar
 * (AuthStatus.profileIncomplete → profil ekranı → `createProfile`).
 */

/** Şifre alfabesi: karışan karakterler yok (0/O, 1/l/I). */
const UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const LOWER = 'abcdefghijkmnopqrstuvwxyz';
const DIGITS = '23456789';
const GROUP = 4;
const GROUPS = 4;

/** Uygulamanın şifre kuralı (`Limits.passwordPattern`): en az bir büyük harf + bir rakam + 8 karakter. */
const PASSWORD_PATTERN = /^(?=.*\p{Lu})(?=.*\d).{8,}$/u;

/**
 * E-postayı kırpar ve izinli alan adlarına (EmailDomainPolicy.allowedDomains) göre doğrular.
 * @param {string|null|undefined} email
 * @param {string[]} domains
 */
function validateEmail(email, domains) {
  const value = (email ?? '').trim();
  if (!value) throw new Error('--email boş olamaz');
  const at = value.lastIndexOf('@');
  if (at <= 0 || at === value.length - 1 || value.indexOf('@') !== at || /\s/.test(value)) {
    throw new Error(`geçersiz e-posta: ${value}`);
  }
  const domain = value.slice(at + 1).replace(/[A-Z]/g, (c) => c.toLowerCase());
  if (!domains.includes(domain)) throw new Error(`alan adı izinli değil: ${domain} (izinli: ${domains.join(', ')})`);
  return value;
}

/**
 * Okunur rastgele şifre: `Xxxx-xxxx-xxxx-xxxx` (19 karakter); ilk grup büyük harfle başlar, son grup rakamla biter.
 * @param {(n: number) => Buffer} randomBytes crypto.randomBytes
 */
function generatePassword(randomBytes) {
  const pick = (alphabet, byte) => alphabet[byte % alphabet.length];
  const mixed = LOWER + DIGITS;
  const bytes = randomBytes(GROUP * GROUPS);
  const chars = [...bytes].map((b) => pick(mixed, b));
  chars[0] = pick(UPPER, bytes[0]);
  chars[chars.length - 1] = pick(DIGITS, bytes[bytes.length - 1]);
  const groups = [];
  for (let i = 0; i < chars.length; i += GROUP) groups.push(chars.slice(i, i + GROUP).join(''));
  const password = groups.join('-');
  if (!PASSWORD_PATTERN.test(password)) throw new Error('üretilen şifre kurala uymuyor');
  return password;
}

/**
 * Yapılacak işlem: yoksa `create`; varsa doğrula (+ istenirse şifreyi yenile). Devre dışı (askıya alınmış) hesap
 * `blocked`: betik etkinleştirmez, askı uygulamadan kaldırılır.
 * @param {{emailVerified: boolean, disabled: boolean}|null} existing
 * @returns {{action: 'create'|'update'|'none'|'blocked', verify: boolean, resetPassword: boolean}}
 */
function planAccount(existing, { resetPassword }) {
  if (!existing) return { action: 'create', verify: true, resetPassword: true };
  if (existing.disabled === true) return { action: 'blocked', verify: false, resetPassword: false };
  const verify = existing.emailVerified !== true;
  const reset = resetPassword === true;
  return { action: verify || reset ? 'update' : 'none', verify, resetPassword: reset };
}

module.exports = { PASSWORD_PATTERN, validateEmail, generatePassword, planAccount };
