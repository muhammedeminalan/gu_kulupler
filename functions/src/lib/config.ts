/**
 * Cloud Functions sabitleri (T-42; sözleşme docs/plans/T-42.md §4, CD-165).
 *
 * Değerlerin Dart karşılıkları `packages/gu_data/lib/src/constants/*` içindedir; burada yalnızca sunucunun
 * kullandıkları tekrarlanır (sunucu paketi Dart paketini içe aktaramaz).
 */

/**
 * Tek bölge sabiti. Firestore `(default)` konumu `nam5` (ABD çoklu bölge; 2026-10-16 CLI ile okundu, kullanıcı kararı H-16:
 * ABD'de kalır) → Firestore tetikleyicileri `us-central1`'de olmalı (PLAN §21; CD-165).
 */
export const REGION = 'us-central1';

/** Sessiz saat ve zamanlanmış görevlerin saat dilimi (Istanbul günü — domain-model §7). */
export const TIME_ZONE = 'Europe/Istanbul';

/** Koleksiyon / belge adları (`FirestoreCollections`). */
export const Col = Object.freeze({
  users: 'users',
  private: 'private',
  account: 'account',
  settings: 'settings',
  clubs: 'clubs',
  events: 'events',
  counter: 'counter',
  rsvps: 'rsvps',
  notifications: 'notifications',
  reports: 'reports',
  memberships: 'memberships',
  contact: 'contact',
  savedPosts: 'savedPosts',
  blocks: 'blocks',
  /** Sunucuya özel push makbuzu (istemciye tamamen kapalı — Rules, C). */
  pushReceipts: 'pushReceipts',
});

/** Push dili (jeton öğesinin isteğe bağlı `locale` alanı; yoksa `tr`). */
export const LOCALES = ['tr', 'en'] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = 'tr';

/** `account.fcmTokens` üst sınırı (`Limits.fcmTokensMax`). */
export const FCM_TOKENS_MAX = 10;

/** Android bildirim kanalları (uygulama B ile aynı kimlikler). */
export const ANDROID_CHANNEL = 'gu_push';
export const ANDROID_QUIET_CHANNEL = 'gu_push_quiet';

/** Geçersiz jetonu bildiren FCM hata kodları: yalnızca bunlar jetonu `fcmTokens`'tan çıkarır. */
export const INVALID_TOKEN_CODES: ReadonlySet<string> = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** Sessiz saat varsayılanları ve deseni (`Limits.quietFromDefault`, `quietToDefault`, `timeOfDayPattern`). */
export const QUIET_FROM_DEFAULT = '22:00';
export const QUIET_TO_DEFAULT = '08:00';
export const TIME_OF_DAY = /^([01]\d|2[0-3]):([0-5]\d)$/;

/** Push metnine giren ad / başlığın en çok karakter sayısı (aşarsa `…` ile kısaltılır). */
export const PUSH_NAME_MAX = 60;

/** Sunucu olay anahtarı: `sha256(girdi).hex` ilk 20 karakter (Rules `[A-Za-z0-9]{20}` ile uyumlu). */
export const EVENT_KEY_LENGTH = 20;

/** Süper admin listesinin modül önbelleği süresi. */
export const SUPER_ADMIN_TTL_MS = 10 * 60 * 1000;

/** `listUsers` sayfa boyu (Auth API üst sınırı). */
export const AUTH_PAGE_SIZE = 1000;

/** Aynı hedefin açık şikayet grubunu okurken en çok belge (grup küçüktür; sınır maliyet içindir). */
export const REPORT_GROUP_SCAN = 100;

/** Terfi adayı tararken en çok bekleyen kaydı (biçimi bozuk kayıt atlanır). */
export const WAITLIST_SCAN = 10;

/** Hesap silme temizliği penceresi ve koşu sınırı (W-91; daha eskisi `tool/admin` betiğiyle). */
export const CLEANUP_MIN_AGE_MS = 60 * 60 * 1000;
export const CLEANUP_MAX_AGE_MS = 72 * 60 * 60 * 1000;
/** Koşu başına en çok bu kadar hesap TEMİZLENİR (boş planlı — zaten temiz — hesaplar sayılmaz). */
export const CLEANUP_MAX_USERS = 50;
/** Tarama sayfa boyu (`startAfter` ile sayfalanır). */
export const CLEANUP_PAGE_SIZE = 50;
/**
 * Koşu süre bütçesi (fonksiyon zaman aşımı 540 sn): sayfa, hesap ve batch öncesi denetlenir; aşılınca koşu durur,
 * kalanı sonraki koşu yapar (T-45 A5-02).
 */
export const CLEANUP_BUDGET_MS = 400 * 1000;
/**
 * Kişisel belgeler (`notifications` / `savedPosts` / `blocks`) okuma sayfası ve yazım batch'i (T-45 A5-02): okuma
 * `orderBy(documentId()).limit(...)` + `startAfter`, yazım bu boyda gruplu batch (her yazım kendi `lastUpdateTime`
 * önkoşuluyla; Firestore batch sınırı 500). Eşitlik süzgeçleri + `__name__` sırası → yeni indeks gerekmez.
 */
export const CLEANUP_PERSONAL_PAGE = 450;
/**
 * Koşu başına, hesap ve koleksiyon başına en çok bu kadar kişisel belge okunur / yazılır (bellek ve süre sınırı —
 * kullanıcı bu belgeleri sınırsız üretebilir). Kalanı sonraki koşu okur: sorgu zaten `isDeleted == false` süzer.
 */
export const CLEANUP_PERSONAL_MAX_PER_USER = 900;

/** `new_report` push'u: süper admin başına bu pencerede en çok bir push (kapsam kilidi — push_guard.ts). */
export const NEW_REPORT_PUSH_WINDOW_MS = 15 * 60 * 1000;

/** Şikayet hedef türleri (`ReportTargetType`); grup anahtarı Rules deseni. */
export const REPORT_TARGET_TYPES: ReadonlySet<string> = new Set(['post', 'comment', 'user', 'club', 'event']);
export const REPORT_TARGET_ID = /^[A-Za-z0-9_-]+$/;
