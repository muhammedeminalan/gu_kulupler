/**
 * Sessiz saat (CD-165 c): tasarım metni "Bu saatlerde bildirim sesi çalmaz" → push ENGELLENMEZ, sessiz teslim
 * edilir. Aralık Europe/Istanbul yerel saatinde `[quietFrom, quietTo)`; gece yarısını aşabilir (22:00–08:00);
 * `from == to` ya da biçimi bozuk değer → sessiz değil.
 */
import { TIME_OF_DAY, TIME_ZONE } from './config';
import { UserSettings } from './preference_filter';

const MINUTES_PER_HOUR = 60;

/** `HH:mm` → günün dakikası; biçim `Limits.timeOfDayPattern` değilse `null`. */
export function minutesOf(value: string): number | null {
  const match = TIME_OF_DAY.exec(value);
  if (!match) return null;
  return Number(match[1]) * MINUTES_PER_HOUR + Number(match[2]);
}

const istanbulClock = new Intl.DateTimeFormat('en-GB', {
  timeZone: TIME_ZONE,
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

/** [now] anının Istanbul yerel saatinde günün dakikası. */
export function istanbulMinutes(now: Date): number {
  let hour = 0;
  let minute = 0;
  for (const part of istanbulClock.formatToParts(now)) {
    if (part.type === 'hour') hour = Number(part.value);
    if (part.type === 'minute') minute = Number(part.value);
  }
  return hour * MINUTES_PER_HOUR + minute;
}

/** [settings] sahibi için [now] anı sessiz saat içinde mi? */
export function isQuietNow(settings: UserSettings, now: Date): boolean {
  if (!settings.quiet) return false;
  const from = minutesOf(settings.quietFrom);
  const to = minutesOf(settings.quietTo);
  if (from === null || to === null || from === to) return false;
  const m = istanbulMinutes(now);
  return from < to ? m >= from && m < to : m >= from || m < to;
}
