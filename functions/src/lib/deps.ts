/**
 * Handler bağımlılıkları (CD-165 e): gövdeler `lib/` altında, dışarıdan verilen [Deps] ile çalışır; `index.ts` /
 * `triggers/*` yalnızca bağlar. Testler handler'ı doğrudan, sahte gönderici ve sahte süper admin dizini ile çağırır.
 */
import type { Firestore } from 'firebase-admin/firestore';
import type { PushSender } from './push_sender';

/** Etkin süper admin uid'leri (Auth custom claim `superadmin === true`, devre dışı olmayan). */
export interface SuperAdminDirectory {
  list(): Promise<string[]>;
}

export interface Deps {
  db: Firestore;
  sender: PushSender;
  superAdmins: SuperAdminDirectory;
  now: () => Date;
}
