// CD-165 c · push yükü: dil grupları, data yalnızca dizge (notificationId, type, dolu refs), kanal / ses / rozet,
// metinde yalnızca kulüp adı ve etkinlik başlığı; ad okunamazsa genel metin.
import { NOTIFICATION_TYPES } from '../src/lib/model';
import { buildPushMessages, tokensFrom } from '../src/lib/push_payload';
import { toMulticast } from '../src/lib/push_sender';
import { clipName, pushText } from '../src/lib/texts';

const refs = { clubId: 'c01', eventId: 'e01', applicantId: 'u_applicant', reportId: 'post_p1', role: 'president' };

describe('push_payload', () => {
  test('jetonlar locale ile gruplanır (yoksa tr), data dizge ve yalnızca dolu refs', () => {
    const tokens = tokensFrom([
      { token: 'a', platform: 'ios' },
      { token: 'b', platform: 'android', locale: 'en' },
      { token: 'a', platform: 'ios' },
      { token: '', platform: 'ios' },
      'bozuk',
    ]);
    const messages = buildPushMessages({
      notificationId: 'role_changed_k_u1',
      type: 'role_changed',
      refs,
      tokens,
      names: { club: 'Robotik' },
      quiet: false,
    });
    expect(messages.map((m) => [m.tokens, m.title])).toEqual([
      [['a'], 'Rolün değişti'],
      [['b'], 'Your role changed'],
    ]);
    expect(messages[0].data).toEqual({ notificationId: 'role_changed_k_u1', type: 'role_changed', ...refs });
    expect(Object.values(messages[0].data).every((v) => typeof v === 'string')).toBe(true);
  });

  test('FCM iletisi: normalde gu_push + ses; sessiz saatte gu_push_quiet + sessiz; rozet yok', () => {
    const base = { tokens: ['t'], title: 'x', body: 'y', data: { type: 'system' } };
    const loud = toMulticast({ ...base, quiet: false });
    const silent = toMulticast({ ...base, quiet: true });
    expect([loud.android?.priority, loud.android?.notification?.channelId, loud.apns?.payload?.aps]).toEqual([
      'high',
      'gu_push',
      { sound: 'default' },
    ]);
    expect([silent.android?.notification?.channelId, silent.apns?.payload?.aps]).toEqual(['gu_push_quiet', {}]);
    expect(JSON.stringify([loud, silent])).not.toContain('badge');
  });

  test('her tür × dil: metinde yalnızca verilen kulüp / etkinlik adı; ad yoksa genel metin; event_reminder dahil boş değil', () => {
    for (const locale of ['tr', 'en'] as const) {
      for (const type of NOTIFICATION_TYPES) {
        const named = pushText(type, { ...refs, textKey: 'welcome' }, locale, { club: '«KULÜP»', event: '«ETK»' });
        const bare = pushText(type, { ...refs, textKey: 'welcome' }, locale, {});
        const strip = (s: string) => s.replace(/«KULÜP»|«ETK»/g, '');
        for (const text of [named, bare]) {
          expect(text.title.length * text.body.length).toBeGreaterThan(0);
          expect(`${text.title} ${text.body}`).not.toMatch(/u_applicant|post_p1|president|\{|\}/);
        }
        expect(JSON.stringify(bare)).not.toMatch(/«/);
        expect(strip(JSON.stringify(named))).not.toMatch(/«|»/);
      }
    }
    expect(pushText('system', { textKey: 'maintenance' }, 'en', {}).title).toBe('Scheduled maintenance');
    expect(pushText('system', { textKey: 'toString' }, 'tr', {})).toEqual({ title: 'GÜ Kulüpler', body: 'Yeni bir bildirimin var.' });
    expect(pushText('surprise', {}, 'en', {}).body).toBe('You have a new notification.');
  });

  test('uzun ad tek satıra iner ve 60 karakterde kesilir', () => {
    expect(clipName(`  Çok\n${'a'.repeat(80)}  `)).toHaveLength(60);
    expect(clipName('   ')).toBeUndefined();
  });
});
