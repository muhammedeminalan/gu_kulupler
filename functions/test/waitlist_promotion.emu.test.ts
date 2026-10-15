// CD-165 b3 · promoteWaitlistOnCancel gövdesi: sıra, kontenjan, yazımlar (manuel promote ile aynı), döngü / çift terfi yok.
import { Timestamp } from 'firebase-admin/firestore';
import { eventKeyOf } from '../src/lib/ids';
import { handleRsvpUpdated } from '../src/lib/waitlist_promotion';
import { emulatorDb, uniq } from './helpers/emulator';

const db = emulatorDb();
const nowMs = Date.now();
const deps = { db, now: () => new Date(nowMs) };

async function seed(event: Record<string, unknown>, club: Record<string, unknown> = {}) {
  const eventId = uniq('e');
  const clubId = uniq('c');
  await db.doc(`clubs/${clubId}`).set({ name: 'Robotik', status: 'active', isDeleted: false, ...club });
  await db.doc(`events/${eventId}`).set({
    clubId,
    title: 'Hackathon',
    status: 'published',
    isDeleted: false,
    capacity: 3,
    goingCount: 1,
    waitlistCount: 2,
    endsAt: Timestamp.fromMillis(nowMs + 86_400_000),
    ...event,
  });
  const rsvp = async (userId: string, status: string, waitlistMinutesAgo?: number) =>
    db.doc(`rsvps/${eventId}_${userId}`).set({
      eventId,
      clubId,
      userId,
      status,
      ticketCode: 'T',
      ...(waitlistMinutesAgo !== undefined ? { waitlistAt: Timestamp.fromMillis(nowMs - waitlistMinutesAgo * 60_000) } : {}),
    });
  await rsvp('u_cancel', 'cancelled');
  await rsvp('u_newer', 'waitlist', 5);
  await rsvp('u_older', 'waitlist', 30);
  return { eventId, clubId };
}

const cancel = (eventId: string, clubId: string) => [
  { eventId, clubId, userId: 'u_cancel', status: 'going' },
  { eventId, clubId, userId: 'u_cancel', status: 'cancelled' },
] as const;

describe('promoteWaitlistOnCancel', () => {
  test('en eski bekleyen terfi eder; sayaçlar, yan belge, bildirim; yeniden teslim ve kendi yazımı ikinci terfi üretmez', async () => {
    const { eventId, clubId } = await seed({});
    const [before, after] = cancel(eventId, clubId);

    expect(await handleRsvpUpdated(deps, 'cloud-event-1', before, after)).toBe('promoted');

    const status = async (u: string) => (await db.doc(`rsvps/${eventId}_${u}`).get()).get('status');
    expect([await status('u_older'), await status('u_newer')]).toEqual(['going', 'waitlist']);
    expect((await db.doc(`events/${eventId}`).get()).data()).toMatchObject({ goingCount: 2, waitlistCount: 1 });
    expect((await db.doc(`events/${eventId}/private/counter`).get()).data()).toMatchObject({
      clubId,
      lastRsvpRef: `rsvps/${eventId}_u_older`,
    });
    const notif = await db.doc(`notifications/waitlist_promoted_${eventKeyOf('cloud-event-1')}_u_older`).get();
    expect(notif.data()).toMatchObject({
      userId: 'u_older',
      type: 'waitlist_promoted',
      refs: { clubId, eventId },
      read: false,
      isDeleted: false,
      deletedAt: null,
      deletedBy: null,
    });
    expect(notif.get('createdAt')).toBeInstanceOf(Timestamp);

    // Aynı olayın yeniden teslimi: yer hâlâ var ama ikinci terfi yok.
    expect(await handleRsvpUpdated(deps, 'cloud-event-1', before, after)).toBe('duplicate');
    // Terfinin kendi yazımı (waitlist → going) tetikleyiciyi yeniden çalıştırır → no-op.
    const promoted = { eventId, clubId, userId: 'u_older' };
    expect(await handleRsvpUpdated(deps, 'cloud-event-2', { ...promoted, status: 'waitlist' }, { ...promoted, status: 'going' })).toBe('ignored');
    expect(await status('u_newer')).toBe('waitlist');
  });

  test('dolu, bitmiş, sınırsız, yayında olmayan etkinlikte ve askıdaki / silinmiş kulüpte terfi yok; yalnızca going → cancelled tetikler', async () => {
    const cases: Array<[Record<string, unknown>, string]> = [
      [{ goingCount: 3 }, 'full'],
      [{ endsAt: Timestamp.fromMillis(nowMs - 1000) }, 'ended'],
      [{ capacity: null }, 'unlimited'],
      [{ status: 'cancelled' }, 'not_published'],
      [{ isDeleted: true }, 'not_published'],
    ];
    for (const [patch, expected] of cases) {
      const { eventId, clubId } = await seed(patch);
      const [before, after] = cancel(eventId, clubId);
      expect([patch, await handleRsvpUpdated(deps, uniq('ev'), before, after)]).toEqual([patch, expected]);
      expect((await db.doc(`rsvps/${eventId}_u_older`).get()).get('status')).toBe('waitlist');
    }
    // Askıdaki / silinmiş kulüp (etkinliği görünmez; manuel terfi Rules `clubLive` ister) → terfi ve push yok.
    for (const club of [{ status: 'suspended' }, { isDeleted: true }]) {
      const { eventId, clubId } = await seed({}, club);
      const [before, after] = cancel(eventId, clubId);
      expect([club, await handleRsvpUpdated(deps, uniq('ev'), before, after)]).toEqual([club, 'not_published']);
      expect((await db.doc(`rsvps/${eventId}_u_older`).get()).get('status')).toBe('waitlist');
    }
    const { eventId, clubId } = await seed({});
    const base = { eventId, clubId, userId: 'u_cancel' };
    expect(await handleRsvpUpdated(deps, uniq('ev'), { ...base, status: 'waitlist' }, { ...base, status: 'cancelled' })).toBe('ignored');
    expect(await handleRsvpUpdated(deps, uniq('ev'), { ...base, status: 'attended' }, { ...base, status: 'going' })).toBe('ignored');
  });
});
