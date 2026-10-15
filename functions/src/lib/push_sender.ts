/**
 * Push gönderici soyutlaması (CD-165 e): handler'lar yalnızca [PushSender] bilir; canlıda [FcmPushSender],
 * emülatörde ve `demo-` projede [LoggingPushSender] (gerçek FCM çağrısı YOK), testte sahte gönderici.
 */
import type { Messaging, MulticastMessage } from 'firebase-admin/messaging';
import { ANDROID_CHANNEL, ANDROID_QUIET_CHANNEL } from './config';
import { eventKeyOf } from './ids';
import { log } from './log';

/** Bir dil grubunun tek çağrısı (≤ 10 jeton). */
export interface PushMessage {
  tokens: string[];
  title: string;
  body: string;
  /** Hepsi dizge: `notificationId`, `type` + `refs`'in dolu alanları. */
  data: Record<string, string>;
  /** Sessiz saat: sessiz kanal, iOS'ta ses yok. */
  quiet: boolean;
}

/** Jeton başına sonuç; başarısızlıkta FCM hata kodu (`messaging/...`). */
export interface PushResult {
  token: string;
  ok: boolean;
  errorCode?: string;
}

export interface PushSender {
  send(message: PushMessage): Promise<PushResult[]>;
}

/**
 * FCM çok-jetonlu ileti. Android `priority: high` + kanal (`gu_push` / sessizde `gu_push_quiet`); iOS
 * `aps.sound = 'default'` (sessizde yok); `badge` gönderilmez (okunmamış sayısı istemci süzgecine bağlı).
 */
export function toMulticast(message: PushMessage): MulticastMessage {
  return {
    tokens: message.tokens,
    notification: { title: message.title, body: message.body },
    data: message.data,
    android: {
      priority: 'high',
      notification: { channelId: message.quiet ? ANDROID_QUIET_CHANNEL : ANDROID_CHANNEL },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: message.quiet ? {} : { sound: 'default' } },
    },
  };
}

/** Canlı gönderici: `sendEachForMulticast` (deploy yalnızca kullanıcı onayıyla). */
export class FcmPushSender implements PushSender {
  constructor(private readonly messaging: Messaging) {}

  async send(message: PushMessage): Promise<PushResult[]> {
    const response = await this.messaging.sendEachForMulticast(toMulticast(message));
    return response.responses.map((r, i) => ({
      token: message.tokens[i],
      ok: r.success,
      ...(r.success ? {} : { errorCode: r.error?.code }),
    }));
  }
}

/**
 * Emülatör göndericisi: FCM'e gitmez; yalnızca türetilmiş anahtar, tür ve jeton SAYISI loglanır (jeton / metin / uid
 * taşıyan bildirim kimliği değil).
 */
export class LoggingPushSender implements PushSender {
  async send(message: PushMessage): Promise<PushResult[]> {
    log.info('push (emülatör — gönderilmedi)', {
      key: eventKeyOf(message.data.notificationId ?? ''),
      type: message.data.type,
      tokens: message.tokens.length,
      quiet: message.quiet,
    });
    return message.tokens.map((token) => ({ token, ok: true }));
  }
}
