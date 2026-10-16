/**
 * Push başlık / metin şablonları, TR ve EN (CD-165 c) — NTF-01 satır metinlerinin (ARB `notifType*`) push
 * karşılığı. KİŞİSEL VERİ YOK: parametre yalnızca kulüp adı (`clubs/{id}.name`) ve etkinlik başlığı
 * (`events/{id}.title`); kişi adı, e-posta, başvuru notu, şikayet nedeni / notu, gönderi metni ve iptal nedeni
 * girmez. Ad okunamazsa aynı türün genel metni kullanılır.
 */
import { Locale, PUSH_NAME_MAX } from './config';
import { NotificationType, Refs } from './model';

/** Şablona girebilen tek adlar. */
export interface PushNames {
  club?: string;
  event?: string;
}

export interface PushText {
  title: string;
  body: string;
}

type Template = (names: PushNames) => PushText;

const APP_NAME = 'GÜ Kulüpler';

/** `system` türünün `refs.textKey` tablosu (`tool/admin/lib/system_notification.js` TEXT_KEYS). */
const SYSTEM: Record<Locale, Record<string, PushText>> = {
  tr: {
    welcome: { title: `${APP_NAME}’e hoş geldin`, body: 'Kampüsteki tüm kulüpler, tek cebinde. Keşfetmeye başla.' },
    maintenance: { title: 'Planlı bakım', body: 'Uygulama Pazar 03:00–04:00 arasında kısa süreli bakımda olacak.' },
  },
  en: {
    welcome: { title: `Welcome to ${APP_NAME}`, body: 'Every club on campus, in your pocket. Start exploring.' },
    maintenance: { title: 'Scheduled maintenance', body: 'The app will be briefly under maintenance Sunday 03:00–04:00.' },
  },
};

/** Tanınmayan tür / `textKey` için genel metin. */
export const GENERIC: Record<Locale, PushText> = {
  tr: { title: APP_NAME, body: 'Yeni bir bildirimin var.' },
  en: { title: APP_NAME, body: 'You have a new notification.' },
};

const TR: Record<Exclude<NotificationType, 'system'>, Template> = {
  application_received: ({ club }) => ({
    title: 'Yeni başvuru',
    body: club ? `${club} kulübüne yeni bir üyelik başvurusu var.` : 'Kulübüne yeni bir üyelik başvurusu var.',
  }),
  application_approved: ({ club }) => ({
    title: 'Başvurun onaylandı',
    body: club ? `${club} üyeliğin onaylandı. Hoş geldin!` : 'Kulüp üyeliğin onaylandı. Hoş geldin!',
  }),
  application_rejected: ({ club }) => ({
    title: 'Başvurun reddedildi',
    body: club
      ? `${club} başvurun bu kez kabul edilmedi. Nedeni görmek için dokun.`
      : 'Kulüp başvurun bu kez kabul edilmedi. Nedeni görmek için dokun.',
  }),
  removed_from_club: ({ club }) => ({
    title: 'Üyelik sona erdi',
    body: club
      ? `${club} üyeliğin kulüp yönetimi tarafından sonlandırıldı.`
      : 'Bir kulüp üyeliğin kulüp yönetimi tarafından sonlandırıldı.',
  }),
  role_changed: ({ club }) => ({
    title: 'Rolün değişti',
    body: club ? `${club} kulübündeki rolün güncellendi.` : 'Kulüpteki rolün güncellendi.',
  }),
  announcement: ({ club }) => ({ title: club ?? 'Yeni duyuru', body: 'Yeni bir duyuru yayınlandı.' }),
  event_new: ({ club, event }) => ({
    title: event ? `Yeni etkinlik: ${event}` : 'Yeni etkinlik',
    body: club ? `${club} yeni bir etkinlik yayınladı. Yerini ayırt.` : 'Bir kulüp yeni bir etkinlik yayınladı. Yerini ayırt.',
  }),
  event_reminder: ({ event }) => ({
    title: event ? `Hatırlatma: ${event}` : 'Etkinlik hatırlatması',
    body: 'Kayıtlı olduğun etkinlik yaklaşıyor.',
  }),
  event_cancelled: ({ event }) => ({
    title: 'Etkinlik iptal edildi',
    body: event ? `${event} iptal edildi.` : 'Kayıtlı olduğun bir etkinlik iptal edildi.',
  }),
  waitlist_promoted: ({ event }) => ({
    title: 'Yerin açıldı!',
    body: event
      ? `${event} için bekleme listesinden kayıtlıya alındın. Biletin hazır.`
      : 'Bekleme listesinden kayıtlıya alındın. Biletin hazır.',
  }),
  report_resolved: () => ({
    title: 'Şikayetin sonuçlandı',
    body: 'Uygulama yöneticileri şikayetini inceledi ve gereken işlemi yaptı.',
  }),
  new_report: () => ({ title: 'Yeni şikayet', body: 'İncelenmeyi bekleyen yeni bir şikayet var.' }),
};

const EN: Record<Exclude<NotificationType, 'system'>, Template> = {
  application_received: ({ club }) => ({
    title: 'New application',
    body: club ? `There is a new membership application for ${club}.` : 'Your club has a new membership application.',
  }),
  application_approved: ({ club }) => ({
    title: 'Application approved',
    body: club ? `Your ${club} membership was approved. Welcome!` : 'Your club membership was approved. Welcome!',
  }),
  application_rejected: ({ club }) => ({
    title: 'Application rejected',
    body: club
      ? `Your ${club} application was not accepted this time. Tap to see why.`
      : 'Your club application was not accepted this time. Tap to see why.',
  }),
  removed_from_club: ({ club }) => ({
    title: 'Membership ended',
    body: club ? `Your ${club} membership was ended by the board.` : 'One of your club memberships was ended by the board.',
  }),
  role_changed: ({ club }) => ({
    title: 'Your role changed',
    body: club ? `Your role in ${club} was updated.` : 'Your club role was updated.',
  }),
  announcement: ({ club }) => ({ title: club ?? 'New announcement', body: 'A new announcement was posted.' }),
  event_new: ({ club, event }) => ({
    title: event ? `New event: ${event}` : 'New event',
    body: club ? `${club} published a new event. Save your spot.` : 'A club published a new event. Save your spot.',
  }),
  event_reminder: ({ event }) => ({
    title: event ? `Reminder: ${event}` : 'Event reminder',
    body: 'An event you registered for is coming up.',
  }),
  event_cancelled: ({ event }) => ({
    title: 'Event cancelled',
    body: event ? `${event} was cancelled.` : 'An event you registered for was cancelled.',
  }),
  waitlist_promoted: ({ event }) => ({
    title: 'A spot opened up!',
    body: event
      ? `You were promoted from the waitlist for ${event}. Your ticket is ready.`
      : 'You were promoted from the waitlist. Your ticket is ready.',
  }),
  report_resolved: () => ({
    title: 'Your report was resolved',
    body: "The app's admins reviewed your report and took action.",
  }),
  new_report: () => ({ title: 'New report', body: 'A new report is waiting for review.' }),
};

const BY_LOCALE: Record<Locale, typeof TR> = { tr: TR, en: EN };

/** Türün şablonu kulüp adı / etkinlik başlığı kullanıyor mu? (Gereksiz okuma yapılmasın.) */
export const NEEDS_CLUB: ReadonlySet<string> = new Set([
  'application_received',
  'application_approved',
  'application_rejected',
  'removed_from_club',
  'role_changed',
  'announcement',
  'event_new',
]);
export const NEEDS_EVENT: ReadonlySet<string> = new Set([
  'event_new',
  'event_reminder',
  'event_cancelled',
  'waitlist_promoted',
]);

/** Adı tek satıra indirip [PUSH_NAME_MAX] karakterde keser; boşsa `undefined`. */
export function clipName(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const flat = value.replace(/\s+/g, ' ').trim();
  if (flat.length === 0) return undefined;
  const chars = Array.from(flat);
  return chars.length <= PUSH_NAME_MAX ? flat : `${chars.slice(0, PUSH_NAME_MAX - 1).join('')}…`;
}

/** [type] bildiriminin [locale] dilindeki push metni. */
export function pushText(type: string, refs: Refs, locale: Locale, names: PushNames): PushText {
  if (type === 'system') {
    const key = refs.textKey;
    return key !== undefined && Object.hasOwn(SYSTEM[locale], key) ? SYSTEM[locale][key] : GENERIC[locale];
  }
  const templates: Record<string, Template> = BY_LOCALE[locale];
  return Object.hasOwn(templates, type) ? templates[type](names) : GENERIC[locale];
}
