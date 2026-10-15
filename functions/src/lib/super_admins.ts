/**
 * `SuperAdminDirectory` canlı uygulaması (CD-165 b2): Auth `listUsers` sayfalama, `customClaims.superadmin === true`
 * ve devre dışı olmayan hesaplar; sonuç modül önbelleğinde 10 dk.
 *
 * Neden Firestore'da tutulan bir admin listesi değil: yetkinin TEK kaynağı ID token'daki `superadmin` claim'idir
 * (`tool/admin/set_superadmin.js`; Firestore alanıyla yetki yükseltme yoktur). İkinci bir liste claim'le
 * kayabilir (geri alınan admin bildirim almaya devam eder) ve kendisi bir yazma yolu / Rules dalı ister.
 * `listUsers` yalnızca şikayet açılınca ve en çok 10 dakikada bir koşar; kullanıcı sayısı (kampüs ölçeği) birkaç
 * sayfayı geçmez → maliyet sınırlı. Claim değişikliği en geç 10 dk sonra yansır.
 */
import type { Auth } from 'firebase-admin/auth';
import { AUTH_PAGE_SIZE, SUPER_ADMIN_TTL_MS } from './config';
import { SuperAdminDirectory } from './deps';

/** `listUsers` için gereken en dar arayüz (testte sahte). */
export type UserLister = Pick<Auth, 'listUsers'>;

export class AuthSuperAdminDirectory implements SuperAdminDirectory {
  private cache: { at: number; uids: string[] } | null = null;

  constructor(
    private readonly auth: UserLister,
    private readonly clock: () => number = Date.now,
    private readonly ttlMs: number = SUPER_ADMIN_TTL_MS,
  ) {}

  async list(): Promise<string[]> {
    const now = this.clock();
    if (this.cache && now - this.cache.at < this.ttlMs) return [...this.cache.uids];
    const uids: string[] = [];
    let pageToken: string | undefined;
    do {
      const page = await this.auth.listUsers(AUTH_PAGE_SIZE, pageToken);
      for (const user of page.users) {
        if (user.customClaims?.superadmin === true && !user.disabled) uids.push(user.uid);
      }
      pageToken = page.pageToken;
    } while (pageToken);
    this.cache = { at: now, uids };
    return [...uids];
  }
}
