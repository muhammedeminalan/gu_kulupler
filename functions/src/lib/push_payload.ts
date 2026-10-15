/**
 * Push yükü (CD-165 c, d): jeton listesi → dil grupları → [PushMessage]. Kişisel veri yalnızca [texts.ts]
 * şablonlarının izin verdiği kulüp adı / etkinlik başlığıdır.
 */
import { DEFAULT_LOCALE, FCM_TOKENS_MAX, Locale } from './config';
import { NotificationType, REF_KEYS, Refs } from './model';
import { PushMessage } from './push_sender';
import { PushNames, pushText } from './texts';

/** `account.fcmTokens[]` öğesi (`FcmTokenModel`; `locale` isteğe bağlı, yoksa `tr`). */
export interface DeviceToken {
  token: string;
  locale: Locale;
}

/** Belgedeki `fcmTokens` dizisinden geçerli, tekil jetonlar (en çok [FCM_TOKENS_MAX]). */
export function tokensFrom(value: unknown): DeviceToken[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const out: DeviceToken[] = [];
  for (const item of value) {
    if (!item || typeof item !== 'object') continue;
    const { token, locale } = item as { token?: unknown; locale?: unknown };
    if (typeof token !== 'string' || token.length === 0 || seen.has(token)) continue;
    seen.add(token);
    out.push({ token, locale: locale === 'en' ? 'en' : DEFAULT_LOCALE });
    if (out.length === FCM_TOKENS_MAX) break;
  }
  return out;
}

/** FCM `data`: hepsi dizge — `notificationId`, `type` ve `refs`'in dolu alanları aynı adlarla. */
export function pushData(notificationId: string, type: NotificationType, refs: Refs): Record<string, string> {
  const data: Record<string, string> = { notificationId, type };
  for (const key of REF_KEYS) {
    const value = refs[key];
    if (typeof value === 'string' && value.length > 0) data[key] = value;
  }
  return data;
}

/** Jetonları dile göre gruplayıp her grup için tek ileti üretir (sıra: `tr`, `en`). */
export function buildPushMessages(input: {
  notificationId: string;
  type: NotificationType;
  refs: Refs;
  tokens: DeviceToken[];
  names: PushNames;
  quiet: boolean;
}): PushMessage[] {
  const byLocale = new Map<Locale, string[]>();
  for (const { token, locale } of input.tokens) {
    const list = byLocale.get(locale) ?? [];
    list.push(token);
    byLocale.set(locale, list);
  }
  const data = pushData(input.notificationId, input.type, input.refs);
  const messages: PushMessage[] = [];
  for (const locale of ['tr', 'en'] as const) {
    const tokens = byLocale.get(locale);
    if (!tokens || tokens.length === 0) continue;
    const text = pushText(input.type, input.refs, locale, input.names);
    messages.push({ tokens, title: text.title, body: text.body, data: { ...data }, quiet: input.quiet });
  }
  return messages;
}
