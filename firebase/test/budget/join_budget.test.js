'use strict';
// T-22 — erişim çağrısı bütçesi: etkinliğe katılım, vazgeçme, yoklama ve terfi (rules-spec §1.8; PLAN §11.3 satır 5).
// Sınır: işlem başına 10, istek başına 20 erişim çağrısı (emülatör ayrı yolu bir kez sayar — helpers/budget.js).
// Ayrı yollar:
//   katıl (members etkinliği, en ağır): etkinlik · users/{uid} · üyelik · kulüp · katılım kaydı = 5
//   vazgeç: etkinlik · katılım kaydı = 2
//   yoklama / terfi (yönetici): etkinlik · yan belge · katılım kaydı · users/{uid} · üyelik = 5
// Ret bütçeden değil kuraldan gelir ("Service call error" yok).
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { readDoc, seedFixture } = require('../helpers/fixtures');
const payloads = require('../helpers/payloads');

const classify = (role, writes) => budget.classify(budget.buildBatch(contextFor(role).firestore(), Object.values(writes)).commit());

describe('bütçe · katılım, vazgeçme, yoklama ve terfi (T-22)', () => {
  test('katıl (public + members), yeniden katıl ve vazgeç bütçe içinde geçer; sayaçsız katılım kuraldan reddedilir', async () => {
    await seedFixture('base');
    const outcome = async (role, writes) => (await classify(role, writes)).outcome;
    expect(await outcome('student', payloads.rsvpJoinWrites({ club: CLUB, uid: 'u_student' }))).toBe(budget.Outcome.ok);
    expect(await outcome('board', payloads.rsvpJoinWrites({ club: CLUB, uid: 'u_board', eventId: 'e_members' }))).toBe(budget.Outcome.ok);
    expect(await outcome('member', payloads.rsvpCancelWrites({ uid: 'u_member' }))).toBe(budget.Outcome.ok);
    expect(await outcome('member', payloads.rsvpRejoinWrites({ uid: 'u_member' }))).toBe(budget.Outcome.ok);
    const alone = { rsvp: payloads.rsvpJoinWrites({ club: CLUB, uid: 'u_pending' }).rsvp };
    expect(await outcome('pending', alone)).toBe(budget.Outcome.permissionDenied);
    expect(await readDoc('events/e_public')).toMatchObject({ goingCount: 3, waitlistCount: 0 });
  });

  test('kontenjan 1: ilk katılım going, ikincisi yalnızca waitlist olarak geçer (going denemesi kuraldan reddedilir)', async () => {
    await seedFixture('base', undefined, { patch: { 'events/e_members': { capacity: 1 } } });
    const join = (role, uid, status) => classify(role, payloads.rsvpJoinWrites({ club: CLUB, uid, eventId: 'e_members', status }));
    expect((await join('member', 'u_member', 'going')).outcome).toBe(budget.Outcome.ok);
    expect((await join('board', 'u_board', 'going')).outcome).toBe(budget.Outcome.permissionDenied);
    expect((await join('board', 'u_board', 'waitlist')).outcome).toBe(budget.Outcome.ok);
    expect(await readDoc('events/e_members')).toMatchObject({ goingCount: 1, waitlistCount: 1 });
  });

  test('yöneticinin yoklaması, geri alması ve terfisi (üç yazımlı işlemler) bütçe içinde geçer', async () => {
    await seedFixture('base');
    expect((await classify('board', payloads.attendWrites({ club: CLUB, uid: 'u_board' }))).outcome).toBe(budget.Outcome.ok);
    expect((await classify('president', payloads.attendWrites({ club: CLUB, uid: 'u_president', attended: false }))).outcome).toBe(budget.Outcome.ok);
    expect((await classify('board', payloads.promoteWrites({ club: CLUB }))).outcome).toBe(budget.Outcome.ok);
    // Danışmanın aynı işlemi bütçeden değil kuraldan reddedilir.
    expect((await classify('advisor', payloads.attendWrites({ club: CLUB, uid: 'u_advisor' }))).outcome).toBe(budget.Outcome.permissionDenied);
    expect(await readDoc('events/e_live')).toMatchObject({ goingCount: 3, waitlistCount: 0, attendedCount: 1 });
  });
});
