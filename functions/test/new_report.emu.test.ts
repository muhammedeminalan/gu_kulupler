// CD-165 b2 · notifyNewReport gövdesi: alıcılar (etkin süper adminler, şikayet eden hariç), T-25 şeması,
// açık grup bildirildiyse yok, yeniden teslimde çift belge yok.
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { eventKeyOf } from '../src/lib/ids';
import { handleReportCreated } from '../src/lib/new_report';
import { emulatorDb, uniq } from './helpers/emulator';

const db = emulatorDb();

async function createReport(reporterId: string, targetId: string, createdAt: Timestamp | FieldValue = FieldValue.serverTimestamp()) {
  const id = `${reporterId}_post_${targetId}`;
  await db.doc(`reports/${id}`).set({
    reporterId,
    targetType: 'post',
    targetId,
    targetClubId: 'c01',
    reason: 'spam',
    note: 'Ayşe çok kötü bir şey yazdı',
    status: 'open',
    isDeleted: false,
    createdAt,
  });
  return { id, data: (await db.doc(`reports/${id}`).get()).data() };
}

describe('notifyNewReport', () => {
  test('yalnızca etkin süper adminler (şikayet eden hariç); şema; yeniden teslim çift yazmaz', async () => {
    const [admin, suspended, reporter, ghost] = [uniq('adm'), uniq('adm'), uniq('rep'), uniq('adm')];
    await db.doc(`users/${admin}`).set({ status: 'active' });
    await db.doc(`users/${suspended}`).set({ status: 'suspended' });
    await db.doc(`users/${reporter}`).set({ status: 'active' });
    const superAdmins = { list: async () => [admin, suspended, reporter, ghost, admin] };
    const report = await createReport(reporter, uniq('p'));

    expect(await handleReportCreated({ db, superAdmins }, report.id, report.data)).toEqual({ written: 1 });
    expect(await handleReportCreated({ db, superAdmins }, report.id, report.data)).toEqual({ written: 0 });

    const key = eventKeyOf(report.id);
    const written = await db.collection('notifications').where('type', '==', 'new_report').where('refs.reportId', '==', `post_${report.data?.targetId}`).get();
    expect(written.docs.map((d) => d.id)).toEqual([`new_report_${key}_${admin}`]);
    const doc = written.docs[0].data();
    expect(Object.keys(doc).sort()).toEqual(['createdAt', 'deletedAt', 'deletedBy', 'isDeleted', 'read', 'refs', 'type', 'updatedAt', 'userId']);
    expect(doc).toMatchObject({ userId: admin, refs: { reportId: `post_${report.data?.targetId}` }, read: false, isDeleted: false });
    expect(JSON.stringify(doc)).not.toMatch(/Ayşe|spam/);
  });

  test('aynı hedefin daha önce açılmış açık şikayeti varsa bildirim yok; eşzamanlı iki şikayetten ilki bildirir', async () => {
    const admin = uniq('adm');
    await db.doc(`users/${admin}`).set({ status: 'active' });
    const superAdmins = { list: async () => [admin] };
    const target = uniq('p');
    const first = await createReport(uniq('rep'), target, Timestamp.fromMillis(Date.now() - 60_000));
    const second = await createReport(uniq('rep'), target, Timestamp.fromMillis(Date.now()));

    // İkisi de diğerini görür: sonraki susar, önceki (tetiklenmesi geç kalsa da) bildirir.
    expect(await handleReportCreated({ db, superAdmins }, second.id, second.data)).toEqual({ written: 0, reason: 'group_notified' });
    expect(await handleReportCreated({ db, superAdmins }, first.id, first.data)).toEqual({ written: 1 });
  });
});
