'use strict';
// T-15 — `reports/{reporterId}_{targetType}_{targetId}` (rules-spec §3.10; PLAN §11.1 satır 12; CD-33).
//
//  1. Rol × işlem matrisi: `expectations/reports.json` (aktif her kullanıcı kendi adına oluşturur;
//     sahibi ve süper admin okur; kulüp yöneticisi başkasının şikayetini okuyamaz; çözme T-37 — `admin.test.js`).
//  2. 6 neden × 5 hedef (CD-33) — değer listeleri Dart enum'larından okunur.
//  3. Alan beyaz listesi, kimlik biçimi, `targetClubId` kuralı, not sınırı (`Limits.reportNoteMax`),
//     başlangıç durumu (`open`, karar alanları boş), sunucu zamanı.
//  4. Null alanın iki biçimi (W-51): `targetClubId` / `action` / `resolvedAt` / `resolvedBy`.
//  5. Hedef doğrulaması (CD-137 madde 8u): hedef belge var olmalı; `targetClubId` hedefin gerçek kulübü.
//  6. T-45 (karar 3): her şikayet günün şikayet sayacıyla AYNI batch'te gider (`payloads.reportWrites`;
//     kota ve sayaç biçimi `report_limit.test.js`). Buradaki vakalar sayacı geçerli tutar: ret şikayetten gelir.
const fs = require('node:fs');
const path = require('node:path');
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { Timestamp, serverTimestamp } = require('firebase/firestore');
const budget = require('../helpers/budget');
const { contextFor, CLUB } = require('../helpers/contexts');
const { readDoc, seedDocs, seedFixture } = require('../helpers/fixtures');
const { runMatrix } = require('../helpers/matrix');
const payloads = require('../helpers/payloads');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const limits = require(path.join(REPO_ROOT, 'tool', 'lib', 'dart_sources.js')).readLimits(REPO_ROOT).ints;
/** Dart enum'unun tel değerleri: `ad('değer')` satırları. */
const enumValues = (file) =>
  [...fs.readFileSync(path.join(REPO_ROOT, 'packages/gu_data/lib/src/models/enums', file), 'utf8').matchAll(/^\s+\w+\('([^']+)'\)[,;]/gm)].map((m) => m[1]);
const REASONS = enumValues('report_reason.dart');
const TARGET_TYPES = enumValues('report_target_type.dart');

const UID = 'u_student';
/** Temel veri kümesindeki gönderi (hedef VAR olmalıdır — CD-137 madde 8u). */
const POST = { type: 'post', id: 'p01', clubId: CLUB };
/** Hedef türü → koleksiyon. */
const COLLECTION_OF = { post: 'posts', comment: 'comments', event: 'events', user: 'users', club: 'clubs' };
const reportPath = (target, uid = UID) => `reports/${uid}_${target.type}_${target.id}`;
const targetOf = (type, id) => ({ type, id, clubId: type === 'user' ? undefined : type === 'club' ? id : CLUB });

const studentDb = () => contextFor('student').firestore();
/** Şikayet + günün sayacı tek batch (ReportRepository.report — T-45). */
const sendReport = (writes) => budget.buildBatch(studentDb(), Object.values(writes)).commit();
/** Bugünün sayacını sıfırlar (kurallar kapalı): günlük kota (T-45) bu dosyanın toplu vakalarını kesmesin. */
const resetCounter = () =>
  seedDocs({ [payloads.reportCounterPath(UID)]: { userId: UID, day: payloads.istanbulDay().day, count: 0, reportId: null, updatedAt: serverTimestamp() } });
const DAY_MS = payloads.DAY_MS;
const ISTANBUL_OFFSET_MS = 3 * 60 * 60 * 1000;
/** Istanbul gün sınırına 5 sn'den az kaldıysa sınırı bekler (sayaç anahtarı ile istek aynı güne düşsün — W-50). */
async function settleDay() {
  const left = DAY_MS - ((Date.now() + ISTANBUL_OFFSET_MS) % DAY_MS);
  if (left < 5000) await new Promise((resolve) => setTimeout(resolve, left + 50));
}

beforeEach(settleDay);
const clientTime = () => Timestamp.fromMillis(Date.now() - 60 * 1000);
const text = (length) => 'a'.repeat(length);
const expectWrite = (request, expected) => (expected === 'allow' ? assertSucceeds(request) : assertFails(request));
const omit = (object, keys) => Object.fromEntries(Object.entries(object).filter(([key]) => !keys.includes(key)));

runMatrix('reports.json');

describe('reports · create — 6 neden × 5 hedef (CD-33)', () => {
  test('Dart enum değerleri: ReportReason 6, ReportTargetType 5', () => {
    expect(REASONS).toEqual(['spam', 'harassment', 'inappropriate', 'misinformation', 'offtopic', 'other']);
    expect(TARGET_TYPES).toEqual(['post', 'comment', 'user', 'club', 'event']);
  });

  test('30 bileşimin tamamı kabul edilir; belge `open` ve karar alanları boş oluşur', async () => {
    await seedFixture('base');
    // Her bileşimin kendi hedef belgesi (kural hedefin varlığını ve kulübünü okur).
    await seedDocs(
      Object.fromEntries(TARGET_TYPES.flatMap((type) => REASONS.map((reason) => [`${COLLECTION_OF[type]}/t_${reason}`, { clubId: CLUB }]))),
    );
    for (const type of TARGET_TYPES) {
      // 30 şikayet tek günün kotasını (Limits.reportDailyLimit) aşar: her hedef türünden önce sayaç sıfırlanır.
      await resetCounter();
      for (const reason of REASONS) {
        const target = targetOf(type, `t_${reason}`);
        await assertSucceeds(sendReport(payloads.reportWrites({ uid: UID, target, extra: { reason } })));
      }
    }
    const sample = await readDoc(reportPath(targetOf('event', 't_offtopic')));
    expect(sample).toMatchObject({ targetType: 'event', targetId: 't_offtopic', targetClubId: CLUB, reason: 'offtopic', status: 'open', reporterId: UID });
    for (const key of ['action', 'resolvedAt', 'resolvedBy']) expect(sample).not.toHaveProperty(key);
    expect(await readDoc(reportPath(targetOf('user', 't_spam')))).not.toHaveProperty('targetClubId');
  });
});

describe('reports · create — alan beyaz listesi, kimlik, sınırlar (rules-spec §3.10 C)', () => {
  const USER = targetOf('user', 'u_member');
  const COMMENT = { type: 'comment', id: 'cm01', clubId: CLUB };
  const CLUB_TARGET = targetOf('club', CLUB);

  // Satır: [başlık, hedef, eklenen / ezilen alanlar, çıkarılan anahtarlar, beklenti, belge yolu?].
  test.each([
    ['tablo dışı neden', POST, { reason: 'abuse' }, [], 'deny'],
    ['neden yok', POST, {}, ['reason'], 'deny'],
    ['tablo dışı hedef türü (message)', { type: 'message', id: 'm1', clubId: CLUB }, {}, [], 'deny'],
    ['reporterId başka kullanıcı', POST, { reporterId: 'u_member' }, [], 'deny'],
    // Hedef yorum: `reports/u_member_post_p01` temel veri kümesinde zaten vardır.
    ['başkası adına şikayet (kimlik başkasının)', COMMENT, { reporterId: 'u_member' }, [], 'deny', reportPath(COMMENT, 'u_member')],
    ['kimlik alanlarla uyuşmuyor (targetId farklı)', POST, { targetId: 'p_baska' }, [], 'deny'],
    ['kimlik alanlarla uyuşmuyor (targetType farklı)', POST, { targetType: 'comment' }, [], 'deny'],
    ['targetId boş', { type: 'post', id: '', clubId: CLUB }, {}, [], 'deny'],
    ['kendi kendini şikayet (targetType user, targetId = uid)', targetOf('user', UID), {}, [], 'deny'],
    ['kullanıcı hedefi: targetClubId yok', USER, {}, [], 'allow'],
    ['kullanıcı hedefi: targetClubId açık null (W-51)', USER, { targetClubId: null }, [], 'allow'],
    ['kullanıcı hedefi: targetClubId dolu', USER, { targetClubId: CLUB }, [], 'deny'],
    ['kulüp hedefi: targetClubId = targetId', CLUB_TARGET, {}, [], 'allow'],
    ['kulüp hedefi: targetClubId başka kulüp', CLUB_TARGET, { targetClubId: 'c02' }, [], 'deny'],
    ['gönderi hedefi: targetClubId yok', POST, {}, ['targetClubId'], 'deny'],
    ['gönderi hedefi: targetClubId boş', POST, { targetClubId: '' }, [], 'deny'],
    ['gönderi hedefi var, kulübü doğru', POST, {}, [], 'allow'],
    ['gönderi hedefi: targetClubId gönderinin kulübü değil (başka kulübe atfetme)', POST, { targetClubId: 'c02' }, [], 'deny'],
    ['gönderi hedefi yok (olmayan gönderi, uydurma kulüp)', { type: 'post', id: 'p_yok', clubId: 'c_fake' }, {}, [], 'deny'],
    ['gönderi hedefi yok (olmayan gönderi, gerçek kulüp)', { type: 'post', id: 'p_yok', clubId: CLUB }, {}, [], 'deny'],
    ['yorum hedefi var, kulübü doğru', COMMENT, {}, [], 'allow'],
    ['yorum hedefi yok', { type: 'comment', id: 'cm_yok', clubId: CLUB }, {}, [], 'deny'],
    ['etkinlik hedefi var, kulübü doğru', { type: 'event', id: 'e_public', clubId: CLUB }, {}, [], 'allow'],
    ['etkinlik hedefi: targetClubId etkinliğin kulübü değil', { type: 'event', id: 'e_public', clubId: 'c02' }, {}, [], 'deny'],
    ['kullanıcı hedefi yok (olmayan kullanıcı)', targetOf('user', 'u_yok'), {}, [], 'deny'],
    ['kulüp hedefi yok (olmayan kulüp)', targetOf('club', 'c_yok'), {}, [], 'deny'],
    ['not reportNoteMax', POST, { note: text(limits.reportNoteMax) }, [], 'allow'],
    ['not reportNoteMax + 1', POST, { note: text(limits.reportNoteMax + 1) }, [], 'deny'],
    ['not dizgi değil', POST, { note: 42 }, [], 'deny'],
    ['not anahtarı yok', POST, {}, ['note'], 'deny'],
    ['status: resolved', POST, { status: 'resolved' }, [], 'deny'],
    ['action dolu', POST, { action: 'dismissed' }, [], 'deny'],
    ['resolvedBy dolu', POST, { resolvedBy: UID }, [], 'deny'],
    ['resolvedAt dolu', POST, { resolvedAt: serverTimestamp() }, [], 'deny'],
    ['beyaz liste dışı alan (priority)', POST, { priority: 'high' }, [], 'deny'],
    ['isDeleted: true', POST, { isDeleted: true }, [], 'deny'],
    ['createdAt istemci saati', POST, { createdAt: clientTime() }, [], 'deny'],
    ['updatedAt yok', POST, {}, ['updatedAt'], 'deny'],
  ])('%s', async (_title, target, extra, removed, expected, docPath = reportPath(target)) => {
    await seedFixture('base');
    const writes = payloads.reportWrites({ uid: UID, target, extra, path: docPath });
    writes.report.data = omit(writes.report.data, removed);
    await expectWrite(sendReport(writes), expected);
    if (expected === 'deny') {
      expect(await readDoc(docPath)).toBeNull();
      expect(await readDoc(payloads.reportCounterPath(UID))).toBeNull();
    }
  });
});
