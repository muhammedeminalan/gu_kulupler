/**
 * Canlı bağımlılıklar (tembel; ilk çağrıda kurulur). Gönderici seçimi: emülatörde (`FUNCTIONS_EMULATOR`) ya da
 * `demo-` projede [LoggingPushSender] — gerçek FCM çağrısı YOK; yalnızca gerçek projede [FcmPushSender].
 */
import { App, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { Deps } from './deps';
import { FcmPushSender, LoggingPushSender, PushSender } from './push_sender';
import { AuthSuperAdminDirectory } from './super_admins';

/** Ortamda FCM'e gidilmemeli mi? (emülatör ya da `demo-` proje) */
export function isOfflineEnvironment(env: NodeJS.ProcessEnv = process.env): boolean {
  const project = env.GCLOUD_PROJECT ?? env.GOOGLE_CLOUD_PROJECT ?? '';
  return env.FUNCTIONS_EMULATOR === 'true' || project.startsWith('demo-');
}

let cached: Deps | null = null;

/** Firebase'in varsayılan uygulama adı. */
const DEFAULT_APP = '[DEFAULT]';

/**
 * Varsayılan Admin uygulaması (yoksa kurulur). `getApps().length === 0` denetimi YETMEZ: firebase-functions v2
 * Firestore tetikleyicisi olay anlık görüntüsünü kendi adlı uygulamasıyla (`__FIREBASE_FUNCTIONS_SDK__`) kurar, liste
 * boş olmaz ve varsayılan uygulama hiç kurulmazdı (`app/no-app` — T-42 uçtan uca testinde yakalandı).
 */
export function defaultApp(): App {
  return getApps().find((app) => app.name === DEFAULT_APP) ?? initializeApp();
}

export function runtimeDeps(): Deps {
  if (cached) return cached;
  const app = defaultApp();
  const sender: PushSender = isOfflineEnvironment() ? new LoggingPushSender() : new FcmPushSender(getMessaging(app));
  cached = {
    db: getFirestore(app),
    sender,
    superAdmins: new AuthSuperAdminDirectory(getAuth(app)),
    now: () => new Date(),
  };
  return cached;
}
