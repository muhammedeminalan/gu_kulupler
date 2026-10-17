'use strict';
// T-37 · tool/admin betiklerinin SAF modülleri (sözleşme docs/plans/T-37.md §4 e). Betikler ÇALIŞTIRILMAZ ve
// `firebase-admin` yüklenmez: koruma kararları (hedef, anahtar yolu, onay kipi), W-91 temizlik planı, danışman
// bağlama (uygulamadaki `AdminRepository.setAdvisor` yüküyle birebir — repository_payloads.json#t37) ve `system`
// bildirimi biçimi doğrudan sınanır.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { TOOL_DIR } = require('./helpers');
const cli = require('../admin/lib/admin_cli');
const { ANON_APPLICANT, buildCleanupPlan } = require('../admin/lib/account_cleanup');
const { buildAdvisorPlan } = require('../admin/lib/advisor_link');
const { EVENT_KEY, buildSystemNotifications, newEventKey } = require('../admin/lib/system_notification');

const REPO = path.resolve(TOOL_DIR, '..');
const contract = require(path.join(REPO, 'firebase/test/contracts/repository_payloads.json'));
const NOW = new Date('2026-10-15T09:00:00Z');
const DAY = 24 * 60 * 60 * 1000;

/** Planın nöbetçilerini sözleşme biçimine çevirir (`@serverTimestamp`, `{"@increment": n}`). */
function normalized(writes) {
  return JSON.parse(JSON.stringify(writes, (_k, v) => {
    if (v && v.$serverTimestamp === true) return '@serverTimestamp';
    if (v && typeof v.$increment === 'number') return { '@increment': v.$increment };
    return v;
  }));
}

/** Planı bellekteki duruma uygular (idempotentlik sınaması): noktalı alan yolu ve sayaç deltası dahil. */
function applyPlan(state, writes) {
  const docOf = (p) => {
    const parts = p.split('/');
    if (p.endsWith('/private/contact')) return [state.contacts, parts[1]];
    if (p.endsWith('/private/account')) return [state, 'account'];
    const table = { memberships: state.memberships, clubs: state.clubs, rsvps: state.rsvps, events: state.events,
      notifications: state.personal.notifications, savedPosts: state.personal.savedPosts, blocks: state.personal.blocks }[parts[0]];
    return [table, parts[1]];
  };
  for (const w of writes) {
    const [table, id] = docOf(w.path);
    const doc = { ...table[id] };
    for (const [key, value] of Object.entries(w.data)) {
      if (value && typeof value.$increment === 'number') doc[key] += value.$increment;
      else if (value && value.$serverTimestamp === true) doc[key] = NOW;
      else if (key.includes('.')) {
        const [outer, inner] = key.split('.');
        doc[outer] = { ...doc[outer], [inner]: value };
      } else doc[key] = value;
    }
    table[id] = doc;
  }
}

test('admin_cli · hedef: emülatör yalnızca demo- proje + yerel adres; gerçek projede anahtar repo DIŞINDA, var, '
  + 'proje kimliği tutarlı', () => {
  const emu = cli.resolveTarget({ emulator: true, project: 'demo-gu-kulupler', key: null }, {});
  assert.deepEqual(emu, { emulator: true, projectId: 'demo-gu-kulupler', env: { ...cli.EMULATOR_HOSTS } });
  assert.throws(() => cli.resolveTarget({ emulator: true, project: 'gu-kulupler', key: null }, {}), /demo-/);
  assert.throws(() => cli.resolveTarget({ emulator: true, project: null, key: null }, {}), /demo-/);
  assert.throws(
    () => cli.resolveTarget({ emulator: true, project: 'demo-x', key: null }, { FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443' }),
    /yerel değil/,
  );

  const io = (files) => ({ repo: '/repo', exists: (p) => p in files, readFile: (p) => files[p] });
  const key = JSON.stringify({ project_id: 'gu-kulupler' });
  assert.throws(() => cli.resolveTarget({ emulator: false, project: null, key: null }, {}, io({})), /anahtarı gerekli/);
  assert.throws(() => cli.resolveTarget({ emulator: false, project: null, key: '/repo/tool/admin/sa.json' }, {}, io({ '/repo/tool/admin/sa.json': key })), /repo içinde/);
  assert.throws(() => cli.resolveTarget({ emulator: false, project: null, key: '/secrets/yok.json' }, {}, io({})), /yok/);
  assert.throws(() => cli.resolveTarget({ emulator: false, project: 'baska', key: '/secrets/sa.json' }, {}, io({ '/secrets/sa.json': key })), /uyuşmuyor/);
  const real = cli.resolveTarget({ emulator: false, project: null, key: null }, { GOOGLE_APPLICATION_CREDENTIALS: '/secrets/sa.json' }, io({ '/secrets/sa.json': key }));
  assert.equal(real.projectId, 'gu-kulupler');
  assert.equal(real.emulator, false);
});

test('admin_cli · onay kipi: --yes yoksa kuru; gerçek projede TTY şart ve proje kimliği birebir; argüman / batch / '
  + 'nöbetçi yardımcıları', () => {
  assert.equal(cli.applyMode({ yes: false, emulator: false, isTty: true }), 'dry');
  assert.equal(cli.applyMode({ yes: false, emulator: true, isTty: true }), 'dry');
  assert.equal(cli.applyMode({ yes: true, emulator: true, isTty: false }), 'apply');
  assert.equal(cli.applyMode({ yes: true, emulator: false, isTty: false }), 'noTty');
  assert.equal(cli.applyMode({ yes: true, emulator: false, isTty: false, panelConfirm: 'gu-kulupler' }), 'panel');
  assert.equal(cli.applyMode({ yes: true, emulator: false, isTty: false, panelConfirm: '' }), 'noTty');
  assert.equal(cli.applyMode({ yes: false, emulator: false, isTty: false, panelConfirm: 'gu-kulupler' }), 'dry');
  assert.equal(cli.applyMode({ yes: true, emulator: false, isTty: true, panelConfirm: 'gu-kulupler' }), 'ask');
  assert.equal(cli.applyMode({ yes: true, emulator: false, isTty: true }), 'ask');
  assert.ok(cli.confirmationMatches(' gu-kulupler\n', 'gu-kulupler'));
  assert.ok(!cli.confirmationMatches('evet', 'gu-kulupler'));
  assert.ok(!cli.confirmationMatches('GU-KULUPLER', 'gu-kulupler'));

  const spec = { values: ['--uid'], flags: ['--yes', '--all-deleted'] };
  assert.deepEqual(cli.parseArgs(['--uid', 'u1', '--all-deleted'], spec), { uid: 'u1', yes: false, allDeleted: true });
  assert.throws(() => cli.parseArgs(['--uid'], spec), /değer ister/);
  assert.throws(() => cli.parseArgs(['--force'], spec), /bilinmeyen/);
  assert.throws(() => cli.parseArgs(['--yes', '--yes'], spec), /iki kez/);

  const w = (n) => ({ op: 'update', path: `x/${n}`, data: {} });
  // Bölünmez gruplar (asıl yazım + sayaç) iki batch'e bölünmez.
  assert.deepEqual(cli.packUnits([[w(1), w(2)], [w(3), w(4)], [w(5)]], 3).map((b) => b.map((x) => x.path)), [['x/1', 'x/2'], ['x/3', 'x/4', 'x/5']]);
  assert.throws(() => cli.packUnits([[w(1), w(2)]], 1), /batch sınırı/);
  const fieldValue = { serverTimestamp: () => 'TS', increment: (n) => `INC${n}` };
  assert.deepEqual(cli.materialize({ a: cli.SERVER_TIME, b: cli.increment(-1), c: { d: [cli.SERVER_TIME] }, e: null }, fieldValue), {
    a: 'TS', b: 'INC-1', c: { d: ['TS'] }, e: null,
  });
});

/** Silinmiş hesabın yarım kalmış temizliği: her kural bir belgede. */
function halfCleanedState() {
  const applicant = { name: 'Ayşe Işık', department: 'd02', year: '2', avatarSeed: 'u_x' };
  const m = (clubId, status, role, extra = {}) => ({ clubId, userId: 'u_x', status, role, applicant, ...extra });
  return {
    uid: 'u_x',
    now: NOW,
    user: { status: 'deleted', isDeleted: true },
    account: { email: 'x@ogr.gumushane.edu.tr', emailLower: 'x@ogr.gumushane.edu.tr', fcmTokens: ['t'] },
    memberships: {
      c01_u_x: m('c01', 'active', 'member'),
      c02_u_x: m('c02', 'pending', 'member'),
      c03_u_x: m('c03', 'active', 'president'),
      c04_u_x: m('c04', 'active', 'advisor'),
      c05_u_x: m('c05', 'left', 'member', { applicant: { ...ANON_APPLICANT } }),
      // Kimlik alanlarla uyuşmuyor: sahiplik kanıtı değil, atlanır.
      'c06_u_x': m('c99', 'active', 'member'),
    },
    contacts: {
      c01_u_x: { email: 'x@ogr.gumushane.edu.tr', emailLower: 'x@ogr.gumushane.edu.tr', note: 'not' },
      c05_u_x: { email: '', emailLower: '', note: '' },
    },
    clubs: {
      c01: { memberCount: 12 },
      c02: { memberCount: 3 },
      c03: { memberCount: 7, presidentId: 'u_x' },
      c04: { memberCount: 9, advisor: { name: 'Dr. X', title: '', userId: 'u_x' } },
      c05: { memberCount: 4 },
    },
    rsvps: {
      e1_u_x: { eventId: 'e1', userId: 'u_x', status: 'going' },
      e2_u_x: { eventId: 'e2', userId: 'u_x', status: 'waitlist' },
      e3_u_x: { eventId: 'e3', userId: 'u_x', status: 'going' },
      e4_u_x: { eventId: 'e4', userId: 'u_x', status: 'attended' },
    },
    events: {
      e1: { endsAt: new Date(NOW.getTime() + DAY), goingCount: 5, waitlistCount: 0 },
      e2: { endsAt: new Date(NOW.getTime() + DAY), goingCount: 10, waitlistCount: 2 },
      e3: { endsAt: new Date(NOW.getTime() - DAY), goingCount: 8, waitlistCount: 0 },
      e4: { endsAt: new Date(NOW.getTime() + DAY), goingCount: 1, waitlistCount: 0 },
    },
    personal: {
      notifications: { n1: { isDeleted: false }, n2: { isDeleted: true } },
      savedPosts: { u_x_p1: { isDeleted: false } },
      blocks: { u_x_u_y: { isDeleted: false } },
    },
  };
}

test('W-91 · temizlik planı: katılım (+ sayaç, biten etkinlik korunur), M14 üyelikler (sayaç aynı grupta, başkan '
  + 'kapatılmaz + uyarı, danışman bağı ayrılır), iletişim / hesap boşalır, kişisel belgeler soft delete; ikinci '
  + 'koşum boş (idempotent); silme yok', () => {
  const state = halfCleanedState();
  const plan = buildCleanupPlan(state);
  assert.equal(plan.skip, null);
  const units = plan.units.map(normalized);
  const all = units.flat();
  assert.ok(all.every((w) => w.op === 'update'), 'yalnızca update — silme yok (D-10)');
  const at = (p) => all.filter((w) => w.path === p).map((w) => w.data);

  // Katılım: vazgeçme ve etkinlik sayacı AYNI grupta; biten / yoklaması alınmış etkinlik kaydı kalır (W-80).
  assert.deepEqual(units.find((u) => u[0].path === 'rsvps/e1_u_x'), [
    { op: 'update', path: 'rsvps/e1_u_x', data: { status: 'cancelled', updatedAt: '@serverTimestamp' } },
    { op: 'update', path: 'events/e1', data: { goingCount: { '@increment': -1 }, updatedAt: '@serverTimestamp' } },
  ]);
  assert.deepEqual(at('events/e2'), [{ waitlistCount: { '@increment': -1 }, updatedAt: '@serverTimestamp' }]);
  assert.deepEqual([at('rsvps/e3_u_x'), at('rsvps/e4_u_x'), at('events/e3')], [[], [], []]);

  // Üyelikler.
  const anon = { ...ANON_APPLICANT };
  assert.deepEqual(units.find((u) => u[0].path === 'memberships/c01_u_x'), [
    { op: 'update', path: 'memberships/c01_u_x', data: { status: 'left', applicant: anon, updatedAt: '@serverTimestamp' } },
    { op: 'update', path: 'clubs/c01', data: { memberCount: { '@increment': -1 }, updatedAt: '@serverTimestamp' } },
    { op: 'update', path: 'memberships/c01_u_x/private/contact', data: { email: '', emailLower: '', note: '', updatedAt: '@serverTimestamp' } },
  ]);
  assert.deepEqual(at('memberships/c02_u_x'), [{ status: 'cancelled', applicant: anon, updatedAt: '@serverTimestamp' }]);
  assert.deepEqual(at('clubs/c02'), []);
  // Etkin başkan: durum değişmez (atama akışı kilitlenmesin — W-90), yalnızca anlık görüntü; sayaç yok; uyarı.
  assert.deepEqual(at('memberships/c03_u_x'), [{ applicant: anon, updatedAt: '@serverTimestamp' }]);
  assert.deepEqual(at('clubs/c03'), []);
  assert.match(plan.warnings.join('\n'), /clubs\/c03: silinmiş hesap etkin BAŞKAN — önce ADM-03'te başkan ata \(W-90/);
  // Danışman: `left`, sayaç yok, kulübün bağı ayrılır (M13).
  assert.deepEqual(at('clubs/c04'), [{ 'advisor.userId': null, updatedAt: '@serverTimestamp' }]);
  assert.deepEqual(at('memberships/c05_u_x'), []);
  assert.deepEqual([at('memberships/c06_u_x'), at('clubs/c99')], [[], []]);

  // Hesap ve kişisel belgeler.
  assert.deepEqual(at('users/u_x/private/account'), [{ email: '', emailLower: '', fcmTokens: [], updatedAt: '@serverTimestamp' }]);
  const softDeleted = { isDeleted: true, deletedAt: '@serverTimestamp', deletedBy: 'u_x', updatedAt: '@serverTimestamp' };
  assert.deepEqual([at('notifications/n1'), at('notifications/n2'), at('savedPosts/u_x_p1'), at('blocks/u_x_u_y')], [[softDeleted], [], [softDeleted], [softDeleted]]);
  assert.deepEqual(plan.counts, { account: 1, rsvps: 2, memberships: 4, contacts: 1, personal: 3 });

  // İdempotent: plan uygulandıktan sonra yeniden planlanan iş yok (başkan uyarısı kalır).
  applyPlan(state, plan.units.flat());
  const again = buildCleanupPlan(state);
  assert.deepEqual(again.units, []);
  assert.equal(again.warnings.length, 1);

  // W-90 akışı: süper admin başkan atayınca silinmiş başkan `board` olur → yeniden koşum onu kapatır (sayaç −1).
  state.memberships.c03_u_x = { ...state.memberships.c03_u_x, role: 'board' };
  const afterAssign = buildCleanupPlan(state);
  assert.deepEqual(normalized(afterAssign.units), [[
    { op: 'update', path: 'memberships/c03_u_x', data: { status: 'left', applicant: anon, updatedAt: '@serverTimestamp' } },
    { op: 'update', path: 'clubs/c03', data: { memberCount: { '@increment': -1 }, updatedAt: '@serverTimestamp' } },
  ]]);

  // Silinmemiş hesap ve sıfırdaki sayaç.
  assert.match(buildCleanupPlan({ ...halfCleanedState(), user: { status: 'active' } }).skip, /silinmemiş/);
  const zero = halfCleanedState();
  zero.clubs.c01.memberCount = 0;
  assert.match(buildCleanupPlan(zero).warnings.join('\n'), /clubs\/c01: memberCount zaten 0/);
});

test('W-91 · bayat danışman bağı: uygulamadaki M14 üyeliği zaten `left` yaptıysa kulübün advisor.userId bağı yine '
  + 'ayrılır (güvenlik incelemesi T-37); ikinci koşum boş', () => {
  const state = halfCleanedState();
  state.memberships = { c07_u_x: { clubId: 'c07', userId: 'u_x', status: 'left', role: 'advisor', applicant: { ...ANON_APPLICANT } } };
  state.contacts = {};
  state.clubs = { c07: { memberCount: 4, advisor: { name: 'Dr. X', title: '', userId: 'u_x' } } };
  state.rsvps = {};
  state.personal = { notifications: {}, savedPosts: {}, blocks: {} };
  state.account = { email: '', emailLower: '', fcmTokens: [] };
  const plan = buildCleanupPlan(state);
  assert.deepEqual(normalized(plan.units), [[
    { op: 'update', path: 'clubs/c07', data: { 'advisor.userId': null, updatedAt: '@serverTimestamp' } },
  ]]);
  applyPlan(state, plan.units.flat());
  assert.deepEqual(buildCleanupPlan(state).units, []);
});

test('K-A · set_advisor planı uygulamadaki AdminRepository.setAdvisor yüküyle BİREBİR (repository_payloads.json#t37: '
  + 'bağla / kaldır); hatalar yazımsız', () => {
  const t37 = contract.t37;
  const scenario = (call) => t37.scenarios.find((s) => s.call === call);
  const seeded = (s, p) => {
    const entry = s.seed[p];
    if (!entry) return null;
    const { $fixture: name, ...fields } = entry;
    return { ...(name ? t37.fixtures[name] : {}), ...fields };
  };

  const bind = scenario('AdminRepository.setAdvisor · bağla (M13)');
  const bound = buildAdvisorPlan({
    clubId: 'c01', uid: 'u_student', remove: false,
    club: seeded(bind, 'clubs/c01'), membership: null, contact: null,
    user: seeded(bind, 'users/u_student'), account: seeded(bind, 'users/u_student/private/account'),
  });
  assert.equal(bound.error, null);
  assert.deepEqual(normalized(bound.writes), bind.writes);

  const unbind = scenario('AdminRepository.setAdvisor · kaldır (M13)');
  const unbound = buildAdvisorPlan({
    clubId: 'c01', uid: 'u_advisor', remove: true,
    club: seeded(unbind, 'clubs/c01'), membership: seeded(unbind, 'memberships/c01_u_advisor'), contact: null,
    user: null, account: null,
  });
  assert.deepEqual(normalized(unbound.writes), unbind.writes);

  const base = {
    clubId: 'c01', uid: 'u_student', remove: false, club: seeded(bind, 'clubs/c01'), membership: null, contact: null,
    user: seeded(bind, 'users/u_student'), account: seeded(bind, 'users/u_student/private/account'),
  };
  const errorOf = (patch) => buildAdvisorPlan({ ...base, ...patch }).error;
  assert.match(errorOf({ club: { ...base.club, advisor: null } }), /danışman kaydı/);
  assert.match(errorOf({ club: { ...base.club, advisor: { name: 'A', title: '', userId: 'u_other' } } }), /başka bir hesap bağlı/);
  assert.match(errorOf({ membership: { clubId: 'c01', userId: 'u_student', status: 'active', role: 'member' } }), /active \/ member/);
  assert.match(errorOf({ user: { ...base.user, status: 'suspended' } }), /etkin değil/);
  assert.match(errorOf({ club: null }), /yok/);
  assert.match(errorOf({ remove: true }), /etkin danışman üyeliği yok/);
  // Bayat bağ (güvenlik incelemesi T-37): danışman hesabını sildi, üyelik `left` ama kulüp onu gösteriyor →
  // yalnızca kulüp bağı ayrılır (yeni danışman bağlanabilsin).
  const stale = buildAdvisorPlan({
    ...base, remove: true,
    club: { ...base.club, advisor: { name: 'A', title: '', userId: 'u_student' } },
    membership: { clubId: 'c01', userId: 'u_student', status: 'left', role: 'advisor' },
  });
  assert.equal(stale.error, null);
  assert.deepEqual(normalized(stale.writes), [
    { op: 'update', path: 'clubs/c01', data: { 'advisor.userId': null, updatedAt: '@serverTimestamp' } },
  ]);
  const already = buildAdvisorPlan({
    ...base,
    club: { ...base.club, advisor: { name: 'A', title: '', userId: 'u_student' } },
    membership: { clubId: 'c01', userId: 'u_student', status: 'active', role: 'advisor' },
  });
  assert.deepEqual(already, { error: null, noop: true, writes: [] });
  // Geçmiş üyelik: priorCount korunur (update), iletişim belgesi varsa yalnızca e-posta.
  const past = buildAdvisorPlan({
    ...base, membership: { clubId: 'c01', userId: 'u_student', status: 'left', role: 'member', priorCount: 2 }, contact: { email: 'eski@x' },
  });
  assert.deepEqual(past.writes.map((w) => [w.op, w.path]), [
    ['update', 'memberships/c01_u_student'], ['update', 'memberships/c01_u_student/private/contact'], ['update', 'clubs/c01'],
  ]);
  assert.ok(!('priorCount' in past.writes[0].data));
});

test('system bildirimi: kimlik system_{eventKey}_{uid}, refs yalnızca textKey, alıcılar tekil; geçersiz textKey / '
  + 'anahtar / alıcı hata', () => {
  const key = newEventKey();
  assert.match(key, EVENT_KEY);
  assert.equal(newEventKey(() => Buffer.alloc(20, 0)), 'A'.repeat(20));
  const writes = normalized(buildSystemNotifications({ textKey: 'maintenance', uids: ['u1', 'u2', 'u1'], eventKey: key }));
  assert.deepEqual(writes.map((w) => w.path), [`notifications/system_${key}_u1`, `notifications/system_${key}_u2`]);
  assert.deepEqual(writes[0], {
    op: 'set',
    path: `notifications/system_${key}_u1`,
    data: {
      userId: 'u1', type: 'system', refs: { textKey: 'maintenance' }, read: false, isDeleted: false,
      createdAt: '@serverTimestamp', updatedAt: '@serverTimestamp', deletedAt: null, deletedBy: null,
    },
  });
  // Sözleşmedeki bildirim biçimiyle aynı alan kümesi (NotificationWriter — t37 report_resolved yazımı).
  const resolved = contract.t37.scenarios.flatMap((s) => s.writes).find((w) => w.path.startsWith('notifications/report_resolved_'));
  assert.deepEqual(Object.keys(writes[0].data).sort(), Object.keys(resolved.data).sort());
  assert.throws(() => buildSystemNotifications({ textKey: 'promo', uids: ['u1'], eventKey: key }), /text-key/);
  assert.throws(() => buildSystemNotifications({ textKey: 'welcome', uids: ['u1'], eventKey: 'kisa' }), /olay anahtarı/);
  assert.throws(() => buildSystemNotifications({ textKey: 'welcome', uids: [], eventKey: key }), /alıcı yok/);
  assert.throws(() => buildSystemNotifications({ textKey: 'welcome', uids: ['a/b'], eventKey: key }), /geçersiz uid/);
});

test('T-45 · S4-02 · tool/admin bağımlılıkları kilitli: package-lock.json commit edilir (CD-40), firebase-admin ana '
  + 'sürümü 13, her paket npm kayıt defterinden bütünlük karmasıyla; kurulum yönergesi `npm ci --ignore-scripts`', () => {
  const fs = require('node:fs');
  const adminDir = path.join(TOOL_DIR, 'admin');
  const manifest = require(path.join(adminDir, 'package.json'));
  const lockPath = path.join(adminDir, 'package-lock.json');
  assert.ok(fs.existsSync(lockPath), 'tool/admin/package-lock.json yok (npm install --package-lock-only --ignore-scripts)');
  const lock = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
  assert.ok(lock.lockfileVersion >= 2, `lockfileVersion ${lock.lockfileVersion}`);
  assert.deepEqual(lock.packages[''].dependencies, manifest.dependencies, 'kilit dosyası package.json ile eşleşmiyor');
  const admin = lock.packages['node_modules/firebase-admin'];
  assert.ok(admin, 'firebase-admin kilitli değil');
  assert.equal(admin.version.split('.')[0], '13');
  for (const [name, entry] of Object.entries(lock.packages)) {
    if (!name || entry.link) continue;
    assert.match(entry.resolved || '', /^https:\/\/registry\.npmjs\.org\//, `${name}: kayıt defteri dışı kaynak`);
    assert.match(entry.integrity || '', /^sha512-/, `${name}: bütünlük karması yok`);
  }
  const hints = ['README.md', 'lib/admin_runtime.js', 'set_superadmin.js']
    .map((file) => fs.readFileSync(path.join(adminDir, file), 'utf8'));
  for (const text of hints) {
    assert.match(text, /npm ci --ignore-scripts/);
    assert.doesNotMatch(text, /cd tool\/admin && npm install\b/);
  }
});
