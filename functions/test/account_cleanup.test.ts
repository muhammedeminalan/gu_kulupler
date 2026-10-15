// CD-165 b4 · temizlik planlayıcısı paritesi: TS portu ile tool/admin/lib/account_cleanup.js aynı girdide aynı
// çıktıyı üretir (birimler, uyarılar, sayımlar, nöbetçiler).
import { buildCleanupPlan, CleanupInput } from '../src/lib/account_cleanup';

// eslint-disable-next-line @typescript-eslint/no-require-imports
const js = require('../../tool/admin/lib/account_cleanup.js') as { buildCleanupPlan: (input: unknown) => unknown };

const now = new Date('2026-10-15T12:00:00Z');
const future = new Date('2026-10-20T12:00:00Z');
const past = new Date('2026-10-14T12:00:00Z');
const uid = 'u_del';

const full: CleanupInput = {
  uid,
  now,
  user: { status: 'deleted' },
  account: { email: 'x@ogr.gumushane.edu.tr', emailLower: 'x@ogr.gumushane.edu.tr', fcmTokens: [{ token: 't' }] },
  memberships: {
    [`c1_${uid}`]: { userId: uid, clubId: 'c1', status: 'active', role: 'member', applicant: { name: 'Ayşe' } },
    [`c2_${uid}`]: { userId: uid, clubId: 'c2', status: 'pending', role: 'member', applicant: { name: 'Ayşe' } },
    [`c3_${uid}`]: { userId: uid, clubId: 'c3', status: 'active', role: 'president', applicant: { name: 'Ayşe' } },
    [`c4_${uid}`]: { userId: uid, clubId: 'c4', status: 'active', role: 'advisor', applicant: { name: 'Ayşe' } },
    [`c5_${uid}`]: { userId: uid, clubId: 'c5', status: 'active', role: 'board', applicant: { name: 'Ayşe' } },
    [`x_${uid}`]: { userId: 'u_other', clubId: 'x', status: 'active', role: 'member' },
  },
  contacts: {
    [`c1_${uid}`]: { email: 'x@ogr.gumushane.edu.tr', emailLower: 'x@ogr.gumushane.edu.tr', note: 'not' },
    [`c2_${uid}`]: { email: '', emailLower: '', note: '' },
  },
  clubs: {
    c1: { memberCount: 3 },
    c2: { memberCount: 1 },
    c3: { memberCount: 4 },
    c4: { memberCount: 2, advisor: { userId: uid } },
    c5: { memberCount: 0 },
  },
  rsvps: {
    [`e1_${uid}`]: { userId: uid, eventId: 'e1', status: 'going' },
    [`e2_${uid}`]: { userId: uid, eventId: 'e2', status: 'waitlist' },
    [`e3_${uid}`]: { userId: uid, eventId: 'e3', status: 'going' },
    [`e4_${uid}`]: { userId: uid, eventId: 'e4', status: 'cancelled' },
    [`e5_${uid}`]: { userId: uid, eventId: 'e5', status: 'going' },
  },
  events: {
    e1: { endsAt: future, goingCount: 5 },
    e2: { endsAt: future, waitlistCount: 0 },
    e3: { endsAt: past, goingCount: 2 },
    e4: { endsAt: future, goingCount: 2 },
    e5: { endsAt: future, goingCount: 1, isDeleted: true },
  },
  personal: {
    notifications: { n1: { isDeleted: false }, n2: { isDeleted: true } },
    savedPosts: { s1: { isDeleted: false } },
    blocks: {},
  },
};

describe('account_cleanup parite (TS = JS)', () => {
  test.each([
    ['tam girdi', full],
    ['silinmemiş hesap', { ...full, user: { status: 'active' } }],
    ['kullanıcı belgesi yok', { ...full, user: null }],
    ['zaten temiz (idempotent ikinci koşu)', { ...full, account: { email: '', emailLower: '', fcmTokens: [] }, memberships: {}, rsvps: {}, personal: { notifications: {}, savedPosts: {}, blocks: {} } }],
  ])('%s', (_name, input) => {
    const ts = buildCleanupPlan(input as CleanupInput);
    expect(ts).toEqual(js.buildCleanupPlan(input));
  });

  test('tam girdi beklenen işleri üretir (biten / silinmiş etkinlik, başkan, sıfır sayaç)', () => {
    const plan = buildCleanupPlan(full);
    expect(plan.counts).toEqual({ account: 1, rsvps: 2, memberships: 5, contacts: 1, personal: 2 });
    expect(plan.warnings).toHaveLength(3);
    expect(plan.units.flat().map((w) => w.path)).not.toContain('rsvps/e3_u_del');
  });
});
