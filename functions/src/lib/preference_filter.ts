/**
 * `NotificationPreferenceFilter` (packages/gu_data) tablosunun BİREBİR kopyası (CD-165 c): sunucu, gelen kutusunda
 * gizlenecek bildirimin push'unu da göndermez. Değişirse iki taraf birlikte değişir (testler aynı satırları sınar).
 *
 * | Koşul | Sonuç |
 * |---|---|
 * | FORCED türleri | her zaman |
 * | application_received ∧ !management | gizli |
 * | application_approved / _rejected ∧ !applicationResults | gizli |
 * | announcement ∧ (!announcements ∨ kulüp sessiz ∨ kulüpte duyuru kapalı) | gizli |
 * | post_new ∧ (!newPosts ∨ kulüp sessiz ∨ kulüpte gönderi kapalı) | gizli |
 * | comment_new ∧ (!newComments ∨ kulüp sessiz) | gizli |
 * | event_new ∧ (!newEvents ∨ kulüp sessiz ∨ kulüpte etkinlik kapalı) | gizli |
 * | event_reminder ∧ !eventReminders | gizli |
 * | system ∧ !system | gizli |
 * | tanınmayan tür | gizli |
 */
import { QUIET_FROM_DEFAULT, QUIET_TO_DEFAULT } from './config';
import { isKnownType, Refs } from './model';

/** Kulüp bazlı tercih (`ClubNotificationPrefsModel`; varsayılan hepsi açık, sessiz değil). */
export interface ClubPrefs {
  announcements: boolean;
  events: boolean;
  posts: boolean;
  muted: boolean;
}

/** `settings/{uid}` (`UserSettingsModel`; belge yoksa `UserSettingsModel.defaults`). */
export interface UserSettings {
  announcements: boolean;
  eventReminders: boolean;
  newEvents: boolean;
  newPosts: boolean;
  newComments: boolean;
  applicationResults: boolean;
  management: boolean;
  system: boolean;
  quiet: boolean;
  quietFrom: string;
  quietTo: string;
  clubs: Record<string, ClubPrefs>;
}

/** Tercihten bağımsız her zaman görünen türler (PLAN §15.5 `force`). */
export const FORCED: ReadonlySet<string> = new Set([
  'removed_from_club',
  'role_changed',
  'event_cancelled',
  'waitlist_promoted',
  'report_resolved',
  'new_report',
]);

const bool = (value: unknown, fallback: boolean): boolean => (typeof value === 'boolean' ? value : fallback);
const str = (value: unknown, fallback: string): string => (typeof value === 'string' ? value : fallback);

function clubPrefsFrom(value: unknown): ClubPrefs {
  const raw = value && typeof value === 'object' ? (value as Record<string, unknown>) : {};
  return {
    announcements: bool(raw.announcements, true),
    events: bool(raw.events, true),
    posts: bool(raw.posts, true),
    muted: bool(raw.muted, false),
  };
}

/** Belge verisinden tercihler; eksik / yanlış tipli alan Dart modelindeki varsayılanı alır. */
export function settingsFrom(data: Record<string, unknown> | undefined): UserSettings {
  const d = data ?? {};
  const clubs: Record<string, ClubPrefs> = {};
  if (d.clubs && typeof d.clubs === 'object') {
    for (const [clubId, prefs] of Object.entries(d.clubs as Record<string, unknown>)) clubs[clubId] = clubPrefsFrom(prefs);
  }
  return {
    announcements: bool(d.announcements, true),
    eventReminders: bool(d.eventReminders, true),
    newEvents: bool(d.newEvents, true),
    newPosts: bool(d.newPosts, true),
    newComments: bool(d.newComments, true),
    applicationResults: bool(d.applicationResults, true),
    management: bool(d.management, true),
    system: bool(d.system, true),
    quiet: bool(d.quiet, false),
    quietFrom: str(d.quietFrom, QUIET_FROM_DEFAULT),
    quietTo: str(d.quietTo, QUIET_TO_DEFAULT),
    clubs,
  };
}

/** [type] türündeki, [refs] referanslı bildirim [settings] sahibine görünür mü? */
export function allows(type: string, refs: Refs, settings: UserSettings): boolean {
  if (!isKnownType(type)) return false;
  if (FORCED.has(type)) return true;
  const club = refs.clubId !== undefined ? settings.clubs[refs.clubId] : undefined;
  const clubMuted = club?.muted ?? false;
  switch (type) {
    case 'application_received':
      return settings.management;
    case 'application_approved':
    case 'application_rejected':
      return settings.applicationResults;
    case 'announcement':
      return settings.announcements && !clubMuted && (club?.announcements ?? true);
    case 'post_new':
      return settings.newPosts && !clubMuted && (club?.posts ?? true);
    case 'comment_new':
      return settings.newComments && !clubMuted;
    case 'event_new':
      return settings.newEvents && !clubMuted && (club?.events ?? true);
    case 'event_reminder':
      return settings.eventReminders;
    case 'system':
      return settings.system;
    default:
      return true;
  }
}
