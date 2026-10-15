/**
 * `sendPushOnNotificationCreated` gövdesi (CD-165 b1): her yeni bildirim belgesi → alıcının cihazlarına push.
 *
 * - **İdempotentlik:** önce `pushReceipts/{notificationId}` `create()`; belge zaten varsa (ALREADY_EXISTS) çıkılır
 *   → bir bildirim için en çok bir push. Makbuz silinmez (D-10); sonuç `update` ile yazılır.
 * - **Atlananlar:** silinmiş belge (`filtered`), `event_reminder` ve bilinmeyen tür (`skipped_type` — Q-07: hatırlatıcı
 *   cihazda yerel, push çift bildirim olurdu), etkin olmayan kullanıcı (`inactive`), tercih süzgeci (`filtered`),
 *   jetonsuz kullanıcı (`no_tokens`).
 * - **Push freni (güvenlik incelemesi — push_guard.ts):** alıcının olayla bağı yoksa `unlinked`; aynı kapsamın ikinci
 *   push'u `throttled` (kapsam kilidi `pushReceipts/once_…`). Bildirim belgesine dokunulmaz (gelen kutusu aynen).
 * - **Sessiz saat:** push engellenmez, sessiz teslim edilir.
 * - **Geçersiz jeton:** yalnızca `INVALID_TOKEN_CODES` → `private/account.fcmTokens`'tan transaction ile çıkarılır.
 * - **Döngü yok:** yazdıkları `pushReceipts` ve `private/account`; ikisi de bildirim üretmez.
 * - Fırlatmaz; kişisel veri loglamaz: bildirim kimliği alıcı / başvuran uid'i taşır → log yalnızca türetilmiş
 *   anahtarı (`key = sha256(notificationId)[0:20]`) yazar.
 */
import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { Col, INVALID_TOKEN_CODES } from './config';
import { Deps } from './deps';
import { eventKeyOf } from './ids';
import { isAlreadyExists, isKnownType, isValidId, NotificationType, refsFrom, Refs } from './model';
import { allows, settingsFrom } from './preference_filter';
import { buildPushMessages, tokensFrom } from './push_payload';
import { gateIdFor, linkOf } from './push_guard';
import { PushResult } from './push_sender';
import { isQuietNow } from './quiet_hours';
import { clipName, NEEDS_CLUB, NEEDS_EVENT, PushNames } from './texts';
import { errorFields, log } from './log';

export type PushStatus =
  | 'sent'
  | 'filtered'
  | 'inactive'
  | 'unlinked'
  | 'no_tokens'
  | 'throttled'
  | 'skipped_type'
  | 'failed';

/** Push üretmeyen türler: `event_reminder` cihazda yerel (Q-07). */
const NO_PUSH: ReadonlySet<string> = new Set(['event_reminder']);

interface Outcome {
  status: PushStatus;
  successCount: number;
  failureCount: number;
}

const outcome = (status: PushStatus, successCount = 0, failureCount = 0): Outcome => ({
  status,
  successCount,
  failureCount,
});

/**
 * [notificationId] belgesinin ([data]) push'unu bir kez gönderir. Döner: makbuz durumu; makbuz zaten varsa
 * `duplicate`, belge biçimsizse `ignored` (makbuz yazılmaz).
 */
export async function handleNotificationCreated(
  deps: Pick<Deps, 'db' | 'sender' | 'now'>,
  notificationId: string,
  data: Record<string, unknown> | undefined,
): Promise<PushStatus | 'duplicate' | 'ignored'> {
  const userId = data?.userId;
  if (!data || !isValidId(notificationId) || !isValidId(userId)) return 'ignored';
  const type = typeof data.type === 'string' ? data.type : 'unknown';
  const key = eventKeyOf(notificationId);
  const receipt = deps.db.collection(Col.pushReceipts).doc(notificationId);
  try {
    await receipt.create({
      userId,
      type,
      status: 'pending',
      successCount: 0,
      failureCount: 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (isAlreadyExists(error)) return 'duplicate';
    log.error('push makbuzu yazılamadı', error, { key });
    return 'failed';
  }

  let result: Outcome;
  try {
    result = await deliver(deps, notificationId, userId, type, data);
  } catch (error) {
    log.error('push gönderimi başarısız', error, { key, type });
    result = outcome('failed');
  }
  try {
    await receipt.update({ ...result, updatedAt: FieldValue.serverTimestamp() });
  } catch (error) {
    log.error('push makbuzu güncellenemedi', error, { key });
  }
  log.info('push', { key, type, ...result });
  return result.status;
}

async function deliver(
  deps: Pick<Deps, 'db' | 'sender' | 'now'>,
  notificationId: string,
  userId: string,
  type: string,
  data: Record<string, unknown>,
): Promise<Outcome> {
  if (data.isDeleted === true) return outcome('filtered');
  if (!isKnownType(type) || NO_PUSH.has(type)) return outcome('skipped_type');

  const { db } = deps;
  const userRef = db.collection(Col.users).doc(userId);
  const [user, settingsDoc, account] = await db.getAll(
    userRef,
    db.collection(Col.settings).doc(userId),
    userRef.collection(Col.private).doc(Col.account),
  );
  if (!user.exists || user.get('status') !== 'active') return outcome('inactive');
  const settings = settingsFrom(settingsDoc.exists ? settingsDoc.data() : undefined);
  const refs = refsFrom(data.refs);
  if (!allows(type, refs, settings)) return outcome('filtered');
  const link = await linkOf(db, type, refs, userId);
  if (link === 'none') return outcome('unlinked');
  const tokens = tokensFrom(account.exists ? account.get('fcmTokens') : undefined);
  if (tokens.length === 0) return outcome('no_tokens');
  const now = deps.now();
  const gateId = gateIdFor(type, refs, userId, link, now);
  if (gateId !== null) {
    try {
      await db.collection(Col.pushReceipts).doc(gateId).create({
        userId,
        type,
        kind: 'gate',
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (isAlreadyExists(error)) return outcome('throttled');
      throw error;
    }
  }

  const messages = buildPushMessages({
    notificationId,
    type,
    refs,
    tokens,
    names: await namesFor(db, type, refs),
    quiet: isQuietNow(settings, now),
  });
  const results: PushResult[] = [];
  for (const message of messages) {
    try {
      results.push(...(await deps.sender.send(message)));
    } catch (error) {
      // Gönderim çağrısı bütünüyle düştü: jetonlara dokunulmaz.
      log.warn('push grubu gönderilemedi', { key: eventKeyOf(notificationId), ...errorFields(error) });
      results.push(...message.tokens.map((token) => ({ token, ok: false })));
    }
  }
  const invalid = results.filter((r) => !r.ok && r.errorCode !== undefined && INVALID_TOKEN_CODES.has(r.errorCode));
  if (invalid.length > 0) await removeTokens(db, userId, invalid.map((r) => r.token), notificationId);
  const successCount = results.filter((r) => r.ok).length;
  const failureCount = results.length - successCount;
  return outcome(successCount > 0 ? 'sent' : 'failed', successCount, failureCount);
}

/** Şablonun istediği kulüp adı / etkinlik başlığı; okunamazsa boş (genel metin). */
async function namesFor(db: Firestore, type: NotificationType, refs: Refs): Promise<PushNames> {
  const names: PushNames = {};
  const reads: Array<Promise<void>> = [];
  if (NEEDS_CLUB.has(type) && isValidId(refs.clubId)) {
    reads.push(
      db.collection(Col.clubs).doc(refs.clubId).get().then((snap) => {
        if (snap.exists && snap.get('isDeleted') !== true) names.club = clipName(snap.get('name'));
      }),
    );
  }
  if (NEEDS_EVENT.has(type) && isValidId(refs.eventId)) {
    reads.push(
      db.collection(Col.events).doc(refs.eventId).get().then((snap) => {
        if (snap.exists && snap.get('isDeleted') !== true) names.event = clipName(snap.get('title'));
      }),
    );
  }
  const settled = await Promise.allSettled(reads);
  if (settled.some((s) => s.status === 'rejected')) log.warn('push adı okunamadı — genel metin', { type });
  return names;
}

/** Geçersiz jetonları `private/account.fcmTokens`'tan çıkarır (transaction: oku → süz → yaz + `updatedAt`). */
async function removeTokens(db: Firestore, userId: string, tokens: string[], notificationId: string): Promise<void> {
  const drop = new Set(tokens);
  const ref = db.collection(Col.users).doc(userId).collection(Col.private).doc(Col.account);
  try {
    const removed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return 0;
      const current = snap.get('fcmTokens');
      if (!Array.isArray(current)) return 0;
      const kept = current.filter((item: unknown) => {
        const token = (item as { token?: unknown } | null)?.token;
        return !(typeof token === 'string' && drop.has(token));
      });
      if (kept.length === current.length) return 0;
      tx.update(ref, { fcmTokens: kept, updatedAt: FieldValue.serverTimestamp() });
      return current.length - kept.length;
    });
    if (removed > 0) log.info('geçersiz jeton temizlendi', { key: eventKeyOf(notificationId), removed });
  } catch (error) {
    log.error('geçersiz jeton temizlenemedi', error, { key: eventKeyOf(notificationId) });
  }
}
