// CD-165 b1 · sendPushOnNotificationCreated gövdesi (Firestore emülatörü 8090 + sahte gönderici).
import { Timestamp } from 'firebase-admin/firestore';
import { log } from '../src/lib/log';
import { handleNotificationCreated } from '../src/lib/send_push';
import { emulatorDb, FakeSender, uniq } from './helpers/emulator';

const db = emulatorDb();
const now = () => new Date('2026-10-15T12:00:00+03:00'); // Istanbul 12:00

const token = (value: string, locale?: string) => ({
  token: value,
  platform: 'ios',
  updatedAt: Timestamp.now(),
  ...(locale ? { locale } : {}),
});

async function seedUser(opts: { status?: string; tokens?: unknown[]; settings?: Record<string, unknown> } = {}) {
  const uid = uniq('u');
  await db.doc(`users/${uid}`).set({ name: 'Ayşe Yılmaz', status: opts.status ?? 'active' });
  await db.doc(`users/${uid}/private/account`).set({
    email: 'ayse@ogr.gumushane.edu.tr',
    emailLower: 'ayse@ogr.gumushane.edu.tr',
    fcmTokens: opts.tokens ?? [],
  });
  if (opts.settings) await db.doc(`settings/${uid}`).set(opts.settings);
  return uid;
}

const note = (uid: string, type: string, refs: Record<string, string>, extra: Record<string, unknown> = {}) => ({
  id: `${type}_${uniq('k')}_${uid}`,
  data: { userId: uid, type, refs, read: false, isDeleted: false, ...extra },
});

describe('sendPushOnNotificationCreated', () => {
  test('aynı belge iki kez tetiklenirse tek push (makbuz); dil grupları; metinde kişisel veri yok', async () => {
    const clubId = uniq('c');
    await db.doc(`clubs/${clubId}`).set({ name: 'Robotik Kulübü' });
    const uid = await seedUser({ tokens: [token('tok-tr'), token('tok-en', 'en')] });
    const n = note(uid, 'application_received', { clubId, applicantId: 'u_basvuran' });
    const sender = new FakeSender();

    expect(await handleNotificationCreated({ db, sender, now }, n.id, n.data)).toBe('sent');
    expect(await handleNotificationCreated({ db, sender, now }, n.id, n.data)).toBe('duplicate');

    expect(sender.calls.map((c) => [c.tokens, c.body])).toEqual([
      [['tok-tr'], 'Robotik Kulübü kulübüne yeni bir üyelik başvurusu var.'],
      [['tok-en'], 'There is a new membership application for Robotik Kulübü.'],
    ]);
    expect(JSON.stringify(sender.calls)).not.toMatch(/Ayşe|ayse@|u_basvuran.*başvur/);
    const receipt = (await db.doc(`pushReceipts/${n.id}`).get()).data();
    expect(receipt).toMatchObject({ userId: uid, type: 'application_received', status: 'sent', successCount: 2, failureCount: 0 });
  });

  test('geçersiz jeton (not-registered / invalid) çıkarılır; başka hata jetona dokunmaz', async () => {
    const uid = await seedUser({ tokens: [token('bad-1'), token('bad-2'), token('flaky'), token('good')] });
    const n = note(uid, 'role_changed', { clubId: 'c_yok', role: 'board' });
    const sender = new FakeSender({
      'bad-1': 'messaging/registration-token-not-registered',
      'bad-2': 'messaging/invalid-registration-token',
      flaky: 'messaging/internal-error',
    });

    expect(await handleNotificationCreated({ db, sender, now }, n.id, n.data)).toBe('sent');

    const left = (await db.doc(`users/${uid}/private/account`).get()).get('fcmTokens') as Array<{ token: string }>;
    expect(left.map((t) => t.token)).toEqual(['flaky', 'good']);
    expect((await db.doc(`pushReceipts/${n.id}`).get()).data()).toMatchObject({ successCount: 1, failureCount: 3 });
    // Kulüp okunamadı → genel metin.
    expect(sender.calls[0].body).toBe('Kulüpteki rolün güncellendi.');
  });

  test('atlananlar: event_reminder, bilinmeyen tür, silinmiş belge, etkin olmayan kullanıcı, tercih, jetonsuz', async () => {
    const tokens = [token('t1')];
    const active = await seedUser({ tokens });
    const suspended = await seedUser({ status: 'suspended', tokens });
    const muted = await seedUser({ tokens, settings: { announcements: false } });
    const noTokens = await seedUser();
    const cases: Array<[ReturnType<typeof note>, string]> = [
      [note(active, 'event_reminder', { clubId: 'c', eventId: 'e' }), 'skipped_type'],
      [note(active, 'brand_new_type', {}), 'skipped_type'],
      [note(active, 'system', { textKey: 'welcome' }, { isDeleted: true }), 'filtered'],
      [note(suspended, 'removed_from_club', { clubId: 'c' }), 'inactive'],
      [note(muted, 'announcement', { clubId: 'c', postId: 'p' }), 'filtered'],
      [note(noTokens, 'waitlist_promoted', { clubId: 'c', eventId: 'e' }), 'no_tokens'],
    ];
    const sender = new FakeSender();
    for (const [n, expected] of cases) {
      expect([n.data.type, await handleNotificationCreated({ db, sender, now }, n.id, n.data)]).toEqual([n.data.type, expected]);
      expect((await db.doc(`pushReceipts/${n.id}`).get()).get('status')).toBe(expected);
    }
    expect(sender.calls).toHaveLength(0);
  });

  test('sessiz saat push\'u engellemez, sessiz teslim eder (forced tür dahil)', async () => {
    const uid = await seedUser({ tokens: [token('t1')], settings: { quiet: true, quietFrom: '11:00', quietTo: '13:00' } });
    const eventId = uniq('e');
    await db.doc(`rsvps/${eventId}_${uid}`).set({ eventId, clubId: 'c', userId: uid, status: 'going' });
    const n = note(uid, 'event_cancelled', { clubId: 'c', eventId });
    const sender = new FakeSender();
    expect(await handleNotificationCreated({ db, sender, now }, n.id, n.data)).toBe('sent');
    expect(sender.calls.map((c) => c.quiet)).toEqual([true]);
  });

  // Güvenlik incelemesi (rules-spec §9.3, R-07 / S-3): Rules fan-out alıcısının bağını doğrulamaz → push freni sunucuda.
  describe('push freni: bağ + kapsam kilidi', () => {
    const at = (iso: string) => () => new Date(iso);
    const send = (n: { id: string; data: Record<string, unknown> }, sender: FakeSender, clock = now) =>
      handleNotificationCreated({ db, sender, now: clock }, n.id, n.data);
    const randomKey = () => uniq('k').padEnd(20, 'x').slice(0, 20);
    const keyed = (uid: string, type: string, refs: Record<string, string>) => {
      const n = note(uid, type, refs);
      return { ...n, id: `${type}_${randomKey()}_${uid}` };
    };

    async function seedClubEvent(visibility: 'public' | 'members') {
      const clubId = uniq('c');
      const eventId = uniq('e');
      await db.doc(`clubs/${clubId}`).set({ name: 'Robotik', status: 'active', isDeleted: false });
      await db.doc(`events/${eventId}`).set({ clubId, title: 'Hesabın askıda: evil.tld', status: 'published', isDeleted: false, visibility });
      return { clubId, eventId };
    }
    const join = (clubId: string, uid: string, status = 'active') =>
      db.doc(`memberships/${clubId}_${uid}`).set({ clubId, userId: uid, status, role: 'member' });

    test('yönetici spam\'i: bağsız alıcıya push yok (unlinked); aynı etkinliğin yinelenen event_new\'i tek push', async () => {
      const { clubId, eventId } = await seedClubEvent('members');
      const member = await seedUser({ tokens: [token('m')] });
      const stranger = await seedUser({ tokens: [token('s')] });
      const pending = await seedUser({ tokens: [token('p')] });
      await join(clubId, member);
      await join(clubId, pending, 'pending');
      const sender = new FakeSender();

      expect(await send(keyed(member, 'event_new', { clubId, eventId }), sender)).toBe('sent');
      // Rules'tan geçen ikinci rastgele anahtarlı belge (10 dk penceresinde sınırsız) → push yok.
      expect(await send(keyed(member, 'event_new', { clubId, eventId }), sender)).toBe('throttled');
      expect(await send(keyed(stranger, 'event_new', { clubId, eventId }), sender)).toBe('unlinked');
      expect(await send(keyed(pending, 'event_new', { clubId, eventId }), sender)).toBe('unlinked');
      expect(await send(note(stranger, 'announcement', { clubId, postId: uniq('p') }), sender)).toBe('unlinked');
      // event_cancelled FORCED: yalnızca katılımı (going / waitlist) olana.
      expect(await send(note(stranger, 'event_cancelled', { clubId, eventId }), sender)).toBe('unlinked');
      await db.doc(`rsvps/${eventId}_${stranger}`).set({ eventId, clubId, userId: stranger, status: 'cancelled' });
      expect(await send(note(stranger, 'event_cancelled', { clubId, eventId }), sender)).toBe('unlinked');
      expect(await send(note(member, 'announcement', { clubId, postId: uniq('p') }), sender)).toBe('sent');

      expect(sender.calls.map((c) => c.tokens)).toEqual([['m'], ['m']]);
      const gates = await db.collection('pushReceipts').where('userId', '==', member).where('kind', '==', 'gate').get();
      expect(gates.docs.map((d) => d.id)).toEqual([expect.stringMatching(new RegExp(`^once_event_new_[0-9a-f]{20}_${member}$`))]);
    });

    test('herkese açık etkinlik: üye olmayana kulüp başına günde bir push; başvuru günde bir; new_report 15 dk\'da bir', async () => {
      const a = await seedClubEvent('public');
      const b = await seedClubEvent('members');
      const stranger = await seedUser({ tokens: [token('s')] });
      const sender = new FakeSender();
      const sameClubSecond = uniq('e');
      await db.doc(`events/${sameClubSecond}`).set({ clubId: a.clubId, title: 'x', status: 'published', isDeleted: false, visibility: 'public' });

      expect(await send(keyed(stranger, 'event_new', a), sender)).toBe('sent');
      expect(await send(keyed(stranger, 'event_new', { clubId: a.clubId, eventId: sameClubSecond }), sender)).toBe('throttled');
      expect(await send(keyed(stranger, 'event_new', a), sender, at('2026-10-16T12:00:00+03:00'))).toBe('sent');
      // Başka kulübün etkinliği public değil → bağ yok; etkinlik başka kulübün ise de yok.
      expect(await send(keyed(stranger, 'event_new', b), sender)).toBe('unlinked');
      expect(await send(keyed(stranger, 'event_new', { clubId: b.clubId, eventId: a.eventId }), sender)).toBe('unlinked');

      const manager = await seedUser({ tokens: [token('mgr')] });
      const apply = (n: number) => ({
        id: `application_received_${a.clubId}_u_app_${n}_${manager}`,
        data: { userId: manager, type: 'application_received', refs: { clubId: a.clubId, applicantId: 'u_app' }, isDeleted: false },
      });
      expect(await send(apply(0), sender)).toBe('sent');
      expect(await send(apply(1), sender)).toBe('throttled');

      const admin = await seedUser({ tokens: [token('adm')] });
      const report = () => keyed(admin, 'new_report', { reportId: `post_${uniq('p')}` });
      expect(await send(report(), sender, at('2026-10-15T12:01:00+03:00'))).toBe('sent');
      expect(await send(report(), sender, at('2026-10-15T12:14:00+03:00'))).toBe('throttled');
      expect(await send(report(), sender, at('2026-10-15T12:16:00+03:00'))).toBe('sent');

      expect(sender.calls.map((c) => c.tokens[0])).toEqual(['s', 's', 'mgr', 'adm', 'adm']);
    });

    test('loglar ham bildirim kimliğini (alıcı / başvuran uid) taşımaz', async () => {
      const spies = (['info', 'warn', 'error'] as const).map((level) => jest.spyOn(log, level));
      const uid = await seedUser({ tokens: [token('bad')] });
      const n = { id: `application_received_c1_u_secret_0_${uid}`, data: { userId: uid, type: 'application_received', refs: { clubId: 'c1', applicantId: 'u_secret' } } };
      await send(n, new FakeSender({ bad: 'messaging/registration-token-not-registered' }));
      const logged = JSON.stringify(spies.flatMap((spy) => spy.mock.calls));
      spies.forEach((spy) => spy.mockRestore());
      expect(logged).toContain('"key"');
      expect(logged).not.toMatch(/u_secret|application_received_c1/);
      expect(logged).not.toContain(uid);
    });
  });
});
