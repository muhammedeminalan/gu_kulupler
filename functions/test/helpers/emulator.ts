/**
 * Emülatör testlerinin ortak yardımcıları. GÜVENLİK: Firestore'a dokunmadan önce adresin yerel olduğu ve kullanıcının
 * geliştirme emülatörü (8080) OLMADIĞI doğrulanır; testler yalnızca `npm test` (emulators:exec, 8090) ile koşar.
 */
import { getApps, initializeApp } from 'firebase-admin/app';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { PushMessage, PushResult, PushSender } from '../../src/lib/push_sender';

export const PROJECT = 'demo-gu-kulupler';

export function emulatorDb(): Firestore {
  const host = process.env.FIRESTORE_EMULATOR_HOST ?? '';
  if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host)) {
    throw new Error(`FIRESTORE_EMULATOR_HOST yerel değil (${host || 'yok'}) — emülatör testleri yalnızca npm test ile`);
  }
  if (host.endsWith(':8080')) throw new Error('8080 kullanıcının geliştirme emülatörü — functions testleri 8090 kullanır');
  if (getApps().length === 0) initializeApp({ projectId: PROJECT });
  const db = getFirestore();
  // Her test dosyası kendi modül kaydını kullanır: gRPC kanalı dosya sonunda kapatılır (jest açık tutamaç bırakmasın).
  afterAll(() => db.terminate());
  return db;
}

let counter = 0;
/** Testler arası çakışmayan kimlik (veri silinmez; her test kendi kimlikleriyle çalışır). */
export const uniq = (prefix: string): string => `${prefix}${Date.now().toString(36)}${(counter++).toString(36)}`;

/** Çağrıları kaydeden sahte gönderici; jeton başına hata kodu programlanabilir. */
export class FakeSender implements PushSender {
  readonly calls: PushMessage[] = [];
  constructor(private readonly failures: Record<string, string> = {}) {}

  async send(message: PushMessage): Promise<PushResult[]> {
    this.calls.push(message);
    return message.tokens.map((token) =>
      this.failures[token] ? { token, ok: false, errorCode: this.failures[token] } : { token, ok: true },
    );
  }
}
