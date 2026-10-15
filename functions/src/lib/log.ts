/**
 * Yapılandırılmış log (firebase-functions logger). Kural: jeton, e-posta, ad, şikayet / gönderi metni LOGLANMAZ —
 * yalnızca belge kimlikleri, tür, durum ve sayılar.
 */
import * as logger from 'firebase-functions/logger';

export const log = {
  info: (message: string, fields: Record<string, unknown> = {}): void => logger.info(message, fields),
  warn: (message: string, fields: Record<string, unknown> = {}): void => logger.warn(message, fields),
  /** Hata nesnesinin yalnızca kodu ve mesajı (yığın ve istek gövdesi yok). */
  error: (message: string, error: unknown, fields: Record<string, unknown> = {}): void =>
    logger.error(message, { ...fields, ...errorFields(error) }),
};

export function errorFields(error: unknown): Record<string, unknown> {
  if (error && typeof error === 'object') {
    const e = error as { code?: unknown; message?: unknown };
    return { errorCode: e.code ?? null, errorMessage: typeof e.message === 'string' ? e.message.slice(0, 200) : null };
  }
  return { errorMessage: String(error).slice(0, 200) };
}
