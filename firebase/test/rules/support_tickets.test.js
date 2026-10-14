'use strict';
// T-28 — `supportTickets/{ticketNo}` (rules-spec §3.15; PLAN §11.1 satır 17).
//
//  1. Rol × işlem matrisi: `expectations/support_tickets.json` (sahibi ve süper admin okur; aktif kullanıcı
//     kendi adına açar; yalnızca süper admin `status` değiştirir; silme yok).
//  2. Talep (C) biçimi: alan beyaz listesi, kimlik ↔ `ticketNo` bağı, numara deseni, konu listesi, mesaj
//     ≤ 500, `status == open`, en çok 1 ek ve ek yolu `support/{ticketNo}/` + dosya adı deseni.
//  3. Numara tekilliği: var olan numaraya yazım (= update) herkes için reddedilir; belge değişmez.
//  4. Durum güncellemesi (U): yalnızca süper admin, yalnızca `open` ↔ `closed`.
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, doc, setDoc, updateDoc } = require('firebase/firestore');
const { contextFor } = require('../helpers/contexts');
const { readDoc, seedDocs, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const BOARD = 'u_board';
const NEW_NO = payloads.NEW_TICKET_NO;
const NEW_PATH = `supportTickets/${NEW_NO}`;
const STUDENT_TICKET = 'supportTickets/GU-ABC234';
const NO_EDIT = Object.freeze({});
const FILE = '20261014T090000Z_0123456789abcdef.jpg';
const dbOf = (role) => contextFor(role).firestore();
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const ticket = (extra, options = {}) => payloads.ticketCreate({ uid: BOARD, ...options }, extra);
const at = (ticketNo) => ({ ticketNo });
const without = (data, key) => Object.fromEntries(Object.entries(data).filter(([name]) => name !== key));
const UID = Object.freeze({ student: 'u_student', board: BOARD, super: 'u_super' });

runMatrix('support_tickets.json');

describe('supportTickets · create — biçim (rules-spec §3.15 C)', () => {
  // Satır: [başlık, yük, beklenti, veri düzenlemesi?, belge yolu?]. Bağlam: yönetim kurulu üyesi (aktif).
  test.each([
    ['istemci biçimli talep (eksiz)', ticket(), 'allow'],
    ['ekli talep (jpg / png / webp)', ticket({}, { attachmentPaths: [payloads.supportAttachmentPath(NEW_NO, FILE.replace('.jpg', '.webp'))] }), 'allow'],
    ['tam 500 karakter mesaj', ticket({ message: 'a'.repeat(500) }), 'allow'],
    ['501 karakter mesaj', ticket({ message: 'a'.repeat(501) }), 'deny'],
    ['boş mesaj', ticket({ message: '' }), 'deny'],
    ['mesaj dizgi değil', ticket({ message: 5 }), 'deny'],
    ['başkası adına (userId)', ticket({ userId: 'u_member' }), 'deny'],
    ['kimlik ↔ ticketNo uyuşmuyor', ticket(at('GU-ABC235')), 'deny'],
    ['numara deseni dışı: karışan karakter (0, 1, I, O)', ticket(at('GU-AB01IO')), 'deny', NO_EDIT, 'supportTickets/GU-AB01IO'],
    ['numara deseni dışı: küçük harf', ticket(at('GU-abc234')), 'deny', NO_EDIT, 'supportTickets/GU-abc234'],
    ['numara deseni dışı: 7 karakter', ticket(at('GU-ABC2345')), 'deny', NO_EDIT, 'supportTickets/GU-ABC2345'],
    ['numara deseni dışı: önek yok', ticket(at('ABC234')), 'deny', NO_EDIT, 'supportTickets/ABC234'],
    ['status closed doğar', ticket({ status: 'closed' }), 'deny'],
    ['bilinmeyen konu', ticket({ subject: 'spam' }), 'deny'],
    ['iki ek (supportAttachmentsMax = 1)', ticket({}, { attachmentPaths: [payloads.supportAttachmentPath(), payloads.supportAttachmentPath(NEW_NO, FILE.replace('.jpg', '.png'))] }), 'deny'],
    ['ek başka talebin klasöründe', ticket({}, { attachmentPaths: [payloads.supportAttachmentPath('GU-ABC234')] }), 'deny'],
    ['ek başka kökte (users/)', ticket({}, { attachmentPaths: [`users/${BOARD}/${FILE}`] }), 'deny'],
    ['ek dosya adı deseni dışı', ticket({}, { attachmentPaths: [`support/${NEW_NO}/ekran.jpg`] }), 'deny'],
    ['ek alt klasörde', ticket({}, { attachmentPaths: [`support/${NEW_NO}/alt/${FILE}`] }), 'deny'],
    ['ek uzantısı izinli değil (.gif)', ticket({}, { attachmentPaths: [`support/${NEW_NO}/${FILE.replace('.jpg', '.gif')}`] }), 'deny'],
    ['attachmentPaths liste değil', ticket({ attachmentPaths: payloads.supportAttachmentPath() }), 'deny'],
    ['attachmentPaths yok', without(ticket(), 'attachmentPaths'), 'deny'],
    ['beyaz liste dışı alan (appVersion)', ticket({ appVersion: '1.0.0' }), 'deny'],
    ['createdAt istemci saati', ticket({ createdAt: Timestamp.fromMillis(Date.now() - 60 * 1000) }), 'deny'],
    ['silinmiş doğan talep', ticket({ isDeleted: true }), 'deny'],
    ['profili tamamlanmamış hesap', ticket(), 'deny', { patch: { [`users/${BOARD}`]: { profileComplete: false } } }],
  ])('%s → %s', async (_title, data, expected, edit = NO_EDIT, path = NEW_PATH) => {
    await seedFixture('base', undefined, edit);
    await expectWrite(setDoc(doc(dbOf('board'), path), data), expected);
    if (expected === 'deny') expect(await readDoc(path)).toBeNull();
    else expect(await readDoc(path)).toMatchObject({ userId: BOARD, ticketNo: NEW_NO, status: 'open', isDeleted: false });
  });
});

describe('supportTickets · numara tekilliği (kimlik = ticketNo)', () => {
  test.each(['student', 'board', 'super'])('%s · var olan numaraya yeniden yazım (= update) → deny; belge değişmez', async (role) => {
    await seedFixture('base');
    const before = await readDoc(STUDENT_TICKET);
    const data = payloads.ticketCreate({ uid: UID[role], ticketNo: 'GU-ABC234' });
    await assertFails(setDoc(doc(dbOf(role), STUDENT_TICKET), data));
    expect(await readDoc(STUDENT_TICKET)).toEqual(before);
  });
});

describe('supportTickets · kabul edilmiş sınırlama: kota yok, fren askı (rules-spec §9.13)', () => {
  // T-28 güvenlik incelemesi (CD-151 (7)): talep sayısı / bekleme süresi Rules'ta sınırlanmaz; tek sunucu
  // freni hesabın askıya alınmasıdır (`activeUser()`). Bekleme kuralı eklenirse bu test bilinçli güncellenir.
  const create = (db, ticketNo) => setDoc(doc(db, `supportTickets/${ticketNo}`), payloads.ticketCreate({ uid: BOARD, ticketNo }));

  test('etkin hesap art arda iki talep açar; askıya alınınca üçüncüsü reddedilir', async () => {
    const docs = await seedFixture('base');
    const db = dbOf('board');
    await assertSucceeds(create(db, 'GU-NEWT23'));
    await assertSucceeds(create(db, 'GU-NEWT24'));
    await seedDocs({ [`users/${BOARD}`]: { ...docs[`users/${BOARD}`], status: 'suspended' } });
    await assertFails(create(db, 'GU-NEWT25'));
    expect(await readDoc('supportTickets/GU-NEWT25')).toBeNull();
  });
});

describe('supportTickets · update — durum (yalnızca süper admin)', () => {
  const update = (role, data) => updateDoc(doc(dbOf(role), STUDENT_TICKET), data);

  test('süper admin kapatır ve yeniden açar; sahibi kapatamaz', async () => {
    await seedFixture('base');
    await assertFails(update('student', { status: 'closed', ...payloads.baseUpdate() }));
    await assertSucceeds(update('super', { status: 'closed', ...payloads.baseUpdate() }));
    expect(await readDoc(STUDENT_TICKET)).toMatchObject({ status: 'closed', message: 'Rules testi destek talebi.' });
    await assertSucceeds(update('super', { status: 'open', ...payloads.baseUpdate() }));
  });

  test.each([
    ['bilinmeyen durum', { status: 'resolved', ...payloads.baseUpdate() }],
    ['durum + başka alan', { status: 'closed', userId: 'u_super', ...payloads.baseUpdate() }],
    ['updatedAt istemci saati', { status: 'closed', updatedAt: Timestamp.fromMillis(Date.now() - 60 * 1000) }],
    ['ek yolu değişimi', { attachmentPaths: [payloads.supportAttachmentPath('GU-ABC234')], ...payloads.baseUpdate() }],
  ])('süper admin: %s → deny', async (_title, data) => {
    await seedFixture('base');
    await assertFails(update('super', data));
    expect(await readDoc(STUDENT_TICKET)).toMatchObject({ status: 'open', userId: 'u_student' });
  });
});
