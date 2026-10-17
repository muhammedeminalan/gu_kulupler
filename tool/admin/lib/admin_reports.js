'use strict';
/**
 * Salt okunur raporlar (user_info.js, stats.js) — biçimleyiciler saf (firebase-admin yüklemez; tool/test ile sınanır).
 * FCM jetonlarının kendisi basılmaz, yalnızca sayı ve platform.
 */

const day = (value) => {
  if (!value) return '—';
  const date = typeof value.toDate === 'function' ? value.toDate() : new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : date.toISOString().replace('T', ' ').slice(0, 16) + ' UTC';
};

const tally = (items, keyOf) => {
  const out = {};
  for (const item of items) {
    const key = keyOf(item) ?? '—';
    out[key] = (out[key] || 0) + 1;
  }
  return Object.entries(out).map(([k, n]) => `${k} ${n}`).join(' · ') || '—';
};

/** Panelin yapılandırılmış sonucu okuması için tek satır öneki (`@@JSON {...}`). */
const JSON_PREFIX = '@@JSON ';
const jsonLine = (data) => JSON_PREFIX + JSON.stringify(data);
const iso = (value) => {
  if (!value) return null;
  const date = typeof value.toDate === 'function' ? value.toDate() : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
};
const countBy = (items, keyOf) => {
  const out = {};
  for (const item of items) {
    const key = keyOf(item) ?? '—';
    out[key] = (out[key] || 0) + 1;
  }
  return out;
};

/**
 * Kullanıcı özeti (panel görünümü için yapılandırılmış). Jetonların kendisi yer almaz.
 * @param {{auth: object, profile: object|null, account: object|null, memberships: object[], rsvps: object[], clubNames?: Record<string, string>}} input
 */
function buildUserSummary({ auth, profile, account, memberships, rsvps, clubNames = {} }) {
  const tokens = Array.isArray(account?.fcmTokens) ? account.fcmTokens : [];
  const live = memberships.filter((m) => !m.isDeleted);
  const liveRsvps = rsvps.filter((r) => !r.isDeleted);
  return {
    uid: auth.uid,
    email: auth.email || null,
    emailVerified: auth.emailVerified === true,
    disabled: auth.disabled === true,
    superadmin: auth.customClaims?.superadmin === true,
    createdAt: iso(auth.metadata?.creationTime),
    lastSignInAt: iso(auth.metadata?.lastSignInTime),
    profile: profile
      ? { name: profile.name || null, status: profile.status || null, deleted: profile.isDeleted === true, complete: profile.profileComplete === true, department: profile.department || null, year: profile.year || null }
      : null,
    devices: { count: tokens.length, platforms: countBy(tokens, (t) => t?.platform) },
    memberships: live.map((m) => ({ clubId: m.clubId, clubName: clubNames[m.clubId] || null, role: m.role || null, status: m.status || null })),
    rsvps: countBy(liveRsvps, (r) => r.status),
  };
}

/**
 * Kullanıcı raporu satırları.
 * @param {{auth: object, profile: object|null, account: object|null, memberships: object[], rsvps: object[]}} input
 */
function formatUserReport({ auth, profile, account, memberships, rsvps }) {
  const tokens = Array.isArray(account?.fcmTokens) ? account.fcmTokens : [];
  const lines = [
    `uid          : ${auth.uid}`,
    `E-posta      : ${auth.email || '—'}  ·  ${auth.emailVerified ? 'doğrulanmış' : 'DOĞRULANMAMIŞ'}`,
    `Hesap        : ${auth.disabled ? 'DEVRE DIŞI' : 'etkin'}  ·  süper admin: ${auth.customClaims?.superadmin === true ? 'EVET' : 'hayır'}`,
    `Oluşturma    : ${day(auth.metadata?.creationTime)}  ·  son giriş: ${day(auth.metadata?.lastSignInTime)}`,
  ];
  if (!profile) {
    lines.push('Profil       : YOK (ilk girişte profil ekranı tamamlanmamış)');
  } else {
    lines.push(`Profil       : ${profile.name || '—'}  ·  durum: ${profile.status || '—'}${profile.isDeleted ? ' (silinmiş)' : ''}  ·  profil ${profile.profileComplete ? 'tamam' : 'eksik'}`);
    lines.push(`Bölüm / sınıf: ${profile.department || '—'} / ${profile.year || '—'}`);
  }
  lines.push(`Bildirim     : ${tokens.length} cihaz${tokens.length ? ` (${tally(tokens, (t) => t?.platform)})` : ' — push gitmez'}`);
  const live = memberships.filter((m) => !m.isDeleted);
  lines.push(`Üyelik       : ${live.length}${live.length ? ` (${tally(live, (m) => m.status)})` : ''}`);
  for (const m of live.slice(0, 20)) lines.push(`  · ${m.clubId}  ${m.role || '—'}  ${m.status || '—'}`);
  if (live.length > 20) lines.push(`  · … ${live.length - 20} üyelik daha`);
  const liveRsvps = rsvps.filter((r) => !r.isDeleted);
  lines.push(`Etkinlik     : ${liveRsvps.length}${liveRsvps.length ? ` (${tally(liveRsvps, (r) => r.status)})` : ''}`);
  return lines;
}

/** İstatistik satırları; [counts] anahtar → sayı. */
function formatStats(counts) {
  const n = (key) => (Number.isFinite(counts[key]) ? counts[key] : '—');
  return [
    `Kullanıcı    : ${n('authUsers')} hesap  ·  ${n('activeUsers')} etkin profil`,
    `Bildirim     : ${n('pushUsers')} kullanıcı / ${n('pushDevices')} cihaz push alabilir`,
    `Kulüp        : ${n('activeClubs')} etkin  ·  ${n('activeMemberships')} etkin üyelik`,
    `Etkinlik     : önümüzdeki 7 günde ${n('upcomingEvents')}`,
    `Gönderi      : son 7 günde ${n('recentPosts')}`,
    `Bekleyen     : ${n('openReports')} açık şikayet  ·  ${n('openTickets')} açık destek talebi`,
  ];
}

module.exports = { JSON_PREFIX, buildUserSummary, formatStats, formatUserReport, jsonLine };
