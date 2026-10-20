// CD-165 c · tercih süzgeci = NotificationPreferenceFilter (packages/gu_data/test/notifications/
// notification_preference_filter_test.dart ile AYNI satırlar).
import { NOTIFICATION_TYPES } from '../src/lib/model';
import { allows, FORCED, settingsFrom } from '../src/lib/preference_filter';

const defaults = settingsFrom(undefined);
const ok = (type: string, settings = defaults, clubId = 'c01') => allows(type, { clubId }, settings);

describe('preference_filter (Dart tablosu birebir)', () => {
  test('varsayılan tercihlerde tanınan her tür görünür, unknown gizli', () => {
    for (const type of NOTIFICATION_TYPES) expect(ok(type)).toBe(true);
    expect(ok('unknown')).toBe(false);
    expect(ok('constructor')).toBe(false);
  });

  test('force türleri her tercih kapalıyken ve kulüp sessizken de görünür', () => {
    const allOff = settingsFrom({
      announcements: false,
      eventReminders: false,
      newEvents: false,
      newPosts: false,
      newComments: false,
      applicationResults: false,
      management: false,
      system: false,
      clubs: { c01: { muted: true } },
    });
    const visible = NOTIFICATION_TYPES.filter((type) => ok(type, allOff));
    expect(new Set(visible)).toEqual(FORCED);
  });

  test('genel tercih → tür tablosu (PLAN §15.5)', () => {
    const cases: Array<[string, Record<string, unknown>]> = [
      ['application_received', { management: false }],
      ['application_approved', { applicationResults: false }],
      ['application_rejected', { applicationResults: false }],
      ['announcement', { announcements: false }],
      ['post_new', { newPosts: false }],
      ['comment_new', { newComments: false }],
      ['event_new', { newEvents: false }],
      ['event_reminder', { eventReminders: false }],
      ['system', { system: false }],
    ];
    for (const [type, patch] of cases) expect([type, ok(type, settingsFrom(patch))]).toEqual([type, false]);
  });

  test('kulüp tercihi: sessiz kulüp duyuru ve yeni etkinliği gizler; tür bazlı kapama yalnızca kendi türünü; başka kulüp etkilenmez', () => {
    const muted = settingsFrom({ clubs: { c01: { muted: true } } });
    const noAnnouncements = settingsFrom({ clubs: { c01: { announcements: false } } });
    expect(ok('announcement', muted)).toBe(false);
    expect(ok('event_new', muted)).toBe(false);
    expect(ok('application_received', muted)).toBe(true);
    expect(ok('announcement', noAnnouncements)).toBe(false);
    expect(ok('event_new', noAnnouncements)).toBe(true);
    expect(ok('announcement', muted, 'c02')).toBe(true);
  });

  test('yanlış tipli alan Dart varsayılanını alır (belge yok = hepsi açık, sessiz değil, 22:00–08:00)', () => {
    expect(settingsFrom({ announcements: 'no', quiet: 1 })).toEqual(defaults);
    expect(defaults).toMatchObject({ quiet: false, quietFrom: '22:00', quietTo: '08:00' });
  });
});
