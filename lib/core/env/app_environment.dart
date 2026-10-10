import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';

/// Çalışma ortamı; [define] `--dart-define=ENV=<değer>` karşılığıdır.
enum AppEnv {
  /// Yerel Firebase emülatörü (Auth, Firestore, Storage).
  emulator('emulator'),

  /// Gerçek Firebase projesi.
  production('production');

  const AppEnv(this.define);

  /// `ENV` derleme tanımının değeri.
  final String define;
}

/// Çalışma ortamı ve emülatör bağlaması (architecture §5, PLAN §10.2; Q-01,
/// Q-03).
///
/// ```sh
/// flutter run --dart-define=ENV=emulator
/// flutter run --dart-define=ENV=emulator --dart-define=EMULATOR_HOST=192.168.1.20
/// ```
///
/// - `ENV` açık verilmezse ortam [AppEnv.production] olur ve debug derlemede
///   uyarı yazılır: emülatör **açıkça** seçilir, sessizce varsayılmaz.
/// - Tanınmayan `ENV` değeri ve emülatör dışı ortamda verilen
///   `EMULATOR_HOST` hatadır ([parse]); uygulama açılmaz. Böylece yazım hatası
///   ("emulatr") geliştiriciyi fark ettirmeden gerçek projeye düşürmez.
/// - **Release derlemesi emülatöre bağlanmaz:** `ENV=emulator` release'te
///   [StateError] verir ([parse]). Emülatör bağlantısı şifresizdir (düz HTTP);
///   mağazaya giden paket e-posta ve şifreyi böyle bir adrese gönderemez.
/// - `EMULATOR_HOST` yalnızca geliştirme ağındaki bir adres olabilir
///   ([isLocalNetworkHost]): `localhost`, özel IPv4 aralıkları, `.local` adı.
/// - Emülatörde servisler varsayılan Firebase uygulamasını **kullanmaz**:
///   [emulatorAppName] adlı ikinci uygulama [emulatorProjectId] kimliğiyle
///   açılır ve üç SDK emülatöre bağlanır. Varsayılan uygulama Android'de
///   `google-services.json`'dan yerel olarak kurulur ve Dart tarafında verilen
///   proje kimliğini yok sayar; emülatör verisi ise proje kimliğine göre
///   ayrılır (seed `demo-gu-kulupler` altına yazar).
/// - Emülatör uygulaması gerçek API anahtarını **taşımaz**
///   ([emulatorApiKey]): Auth isteği proje kimliğine değil API anahtarına göre
///   yönlenir; sahte anahtarla emülatöre bağlanmamış bir Auth örneği gerçek
///   projede hesap açamaz, oturum da açamaz.
/// - Servis örnekleri yalnızca [auth], [firestore] ve [storage] üzerinden
///   alınır; `FirebaseAuth.instance` / `FirebaseFirestore.instance` /
///   `FirebaseStorage.instance` başka dosyada çağrılmaz. [configure]
///   tamamlanmadan bu örnekler istenirse [StateError] verilir (yarım kalan
///   kurulum sessizce gerçek projeye düşmez).
abstract final class AppEnvironment {
  /// `ENV` derleme tanımının ham değeri; verilmediyse boş.
  static const String rawEnv = String.fromEnvironment('ENV');

  /// `EMULATOR_HOST` derleme tanımının ham değeri; verilmediyse boş.
  static const String rawEmulatorHost = String.fromEnvironment('EMULATOR_HOST');

  /// `ENV` tanımı emülatör mü? (`--dart-define=ENV=emulator`) Derleme
  /// sabitidir; ortamın doğrulanmış hali [configured]'dır (release derlemede
  /// bu tanım [parse] hatasıdır).
  static const bool isEmulator = rawEnv == 'emulator';

  /// DebugMenu derlemeye girsin mi? Tek tanım (K-E, CD-69): release
  /// derlemede `const false` olduğundan dal ağaçtan düşer.
  static const bool debugMenuEnabled =
      !kReleaseMode && String.fromEnvironment('ENV') == 'emulator';

  /// Auth emülatörü portu (`firebase.json` `emulators.auth.port`).
  static const int authPort = 9099;

  /// Firestore emülatörü portu (`firebase.json` `emulators.firestore.port`).
  static const int firestorePort = 8080;

  /// Storage emülatörü portu (`firebase.json` `emulators.storage.port`).
  static const int storagePort = 9199;

  /// Android emülatöründen geliştirme makinesinin `localhost`'u.
  static const String androidEmulatorHost = '10.0.2.2';

  /// iOS simülatörü ve masaüstünde emülatör adresi.
  static const String localEmulatorHost = 'localhost';

  /// Emülatörün proje kimliği (`firebase emulators:start --project …`).
  /// `demo-` öneki Firestore ve Storage için gerçek bir projeye çözülemez;
  /// Auth'u [emulatorApiKey] korur.
  static const String emulatorProjectId = 'demo-gu-kulupler';

  /// Emülatör uygulamasının API anahtarı. Gerçek bir anahtar **değildir**
  /// (gerçek anahtarlar `AIza` ile başlar); yalnızca Firebase SDK'larının
  /// biçim denetimini geçer: `A` ile başlayan 39 karakter, `[A-Za-z0-9_-]`.
  /// Auth emülatörü anahtarı doğrulamaz; gerçek Auth sunucusu bu anahtarı
  /// reddeder.
  static const String emulatorApiKey =
      'AEMULATOR-ONLY_demo-gu-kulupler_NOTREAL';

  /// Emülatördeki Storage kovası (seed betiğinin varsayılanı).
  static const String emulatorStorageBucket =
      '$emulatorProjectId.firebasestorage.app';

  /// Emülatöre bağlanan ikinci Firebase uygulamasının adı.
  static const String emulatorAppName = 'gu-emulator';

  /// Firestore kalıcı önbellek boyutu: 100 MB (Q-12).
  static const int firestoreCacheSizeBytes = 100 * 1024 * 1024;

  static final RegExp _ipv4Pattern = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
  );

  static final RegExp _mdnsPattern = RegExp(
    r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.local$',
  );

  /// [configure] tamamlandığında doğrulanmış ortam; öncesinde `null`.
  static AppEnv? _configured;

  /// Geçerli ortam ([rawEnv] ve [rawEmulatorHost] tanımlarından).
  static AppEnv get current => parse(rawEnv, rawEmulatorHost: rawEmulatorHost);

  /// Emülatör adresi ([rawEmulatorHost] ya da platform varsayılanı).
  static String get emulatorHost => resolveHost(
    override: rawEmulatorHost,
    platform: defaultTargetPlatform,
    isWeb: kIsWeb,
  );

  /// `ENV` tanımını ortama çevirir.
  ///
  /// Boş → [AppEnv.production] (açık seçim yok). `emulator` / `production`
  /// dışındaki değer ve emülatör dışı ortamda dolu [rawEmulatorHost]
  /// [ArgumentError] fırlatır. [release] derlemede `emulator` [StateError]
  /// fırlatır: sessizce production'a çevrilmez, uygulama açılmaz.
  static AppEnv parse(
    String rawEnv, {
    required String rawEmulatorHost,
    bool release = kReleaseMode,
  }) {
    final env = switch (rawEnv) {
      '' => AppEnv.production,
      _ => AppEnv.values.firstWhere(
        (candidate) => candidate.define == rawEnv,
        orElse: () => throw ArgumentError.value(
          rawEnv,
          'ENV',
          'emulator ya da production olmalı',
        ),
      ),
    };
    if (env != AppEnv.emulator && rawEmulatorHost.isNotEmpty) {
      throw ArgumentError.value(
        rawEmulatorHost,
        'EMULATOR_HOST',
        'yalnızca ENV=emulator ile verilir',
      );
    }
    if (env == AppEnv.emulator && release) {
      throw StateError(
        'ENV=emulator release derlemesinde kullanılamaz: emülatör bağlantısı '
        'şifresizdir.',
      );
    }
    return env;
  }

  /// [host] yalnızca geliştirme ağında çözülen bir adres mi: `localhost`,
  /// `.local` (mDNS) adı ya da özel IPv4 aralığı (127/8, 10/8, 172.16/12,
  /// 192.168/16 — Android emülatörünün `10.0.2.2` adresi dahil). Genel alan
  /// adları ve genel IP'ler değildir.
  static bool isLocalNetworkHost(String host) {
    if (host == localEmulatorHost || _mdnsPattern.hasMatch(host)) return true;
    final match = _ipv4Pattern.firstMatch(host);
    if (match == null) return false;
    final octets = [for (var i = 1; i <= 4; i++) int.parse(match.group(i)!)];
    if (octets.any((octet) => octet > 255)) return false;
    final first = octets[0];
    final second = octets[1];
    return first == 127 ||
        first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  /// Emülatör adresini çözer: [override] doluysa o (yalnızca
  /// [isLocalNetworkHost] adresi; port ve şema yazılmaz — aksi
  /// [ArgumentError]), Android'de [androidEmulatorHost], diğer platformlarda
  /// [localEmulatorHost].
  static String resolveHost({
    required String override,
    required TargetPlatform platform,
    bool isWeb = false,
  }) {
    if (override.isNotEmpty) {
      if (!isLocalNetworkHost(override)) {
        throw ArgumentError.value(
          override,
          'EMULATOR_HOST',
          'yalnızca localhost, .local adı ya da özel ağ IPv4 adresi '
              '(127/8, 10/8, 172.16/12, 192.168/16); port ve şema olmadan',
        );
      }
      return override;
    }
    if (!isWeb && platform == TargetPlatform.android) {
      return androidEmulatorHost;
    }
    return localEmulatorHost;
  }

  /// Emülatör uygulamasının seçenekleri: [base] (varsayılan uygulama) ile
  /// aynı; API anahtarı, proje kimliği ve kova emülatörünkidir (gerçek
  /// projenin anahtarı taşınmaz).
  static FirebaseOptions emulatorOptions(FirebaseOptions base) => base.copyWith(
    apiKey: emulatorApiKey,
    projectId: emulatorProjectId,
    storageBucket: emulatorStorageBucket,
  );

  /// [configure] ile kurulmuş, doğrulanmış ortam. Kurulum tamamlanmadıysa
  /// (çağrılmadı ya da hata verdi) [StateError].
  static AppEnv get configured =>
      _configured ??
      (throw StateError(
        'AppEnvironment.configure() tamamlanmadan Firebase servis örneği '
        'istenemez.',
      ));

  /// Servislerin kullanacağı Firebase uygulaması: emülatörde
  /// [emulatorAppName], üretimde varsayılan uygulama. Ortam derleme
  /// sabitinden değil [configured] değerinden okunur: yarım kalan kurulumda
  /// [StateError] verir, varsayılan (gerçek) uygulamaya düşmez.
  static FirebaseApp get app => switch (configured) {
    AppEnv.emulator => Firebase.app(emulatorAppName),
    AppEnv.production => Firebase.app(),
  };

  /// Ortamın Auth örneği.
  static FirebaseAuth get auth => FirebaseAuth.instanceFor(app: app);

  /// Ortamın Firestore örneği.
  static FirebaseFirestore get firestore =>
      FirebaseFirestore.instanceFor(app: app);

  /// Ortamın Storage örneği.
  static FirebaseStorage get storage => FirebaseStorage.instanceFor(app: app);

  /// Ortamı kurar; `Firebase.initializeApp` sonrasında, herhangi bir
  /// Firebase çağrısından **önce** bir kez çağrılır.
  ///
  /// Emülatörde ikinci uygulamayı açar ve üç SDK'yı emülatöre bağlar; her
  /// iki ortamda Firestore kalıcı önbelleğini ayarlar. Hata yutulmaz:
  /// bağlama başarısızsa uygulama açılmaz ve [configured] boş kalır (servis
  /// örnekleri [StateError] verir).
  static Future<void> configure() async {
    final env = current;
    if (rawEnv.isEmpty && !kReleaseMode) {
      AppLogger.warn(
        'ENV verilmedi: ortam production (gerçek proje). Emülatör için '
        '--dart-define=ENV=emulator',
      );
    }
    if (env == AppEnv.production) {
      applyFirestoreSettings(
        FirebaseFirestore.instanceFor(app: Firebase.app()),
      );
      _configured = env;
      return;
    }
    // Adres, ikinci uygulama açılmadan önce doğrulanır.
    final host = emulatorHost;
    final emulatorApp = await Firebase.initializeApp(
      name: emulatorAppName,
      options: emulatorOptions(Firebase.app().options),
    );
    final emulatorFirestore = FirebaseFirestore.instanceFor(app: emulatorApp);
    applyFirestoreSettings(emulatorFirestore);
    await bindEmulators(
      host: host,
      auth: FirebaseAuth.instanceFor(app: emulatorApp),
      firestore: emulatorFirestore,
      storage: FirebaseStorage.instanceFor(app: emulatorApp),
    );
    // Yalnızca üç SDK da emülatöre bağlandıktan sonra örnekler verilir.
    _configured = env;
    AppLogger.info(
      'Emülatör: $emulatorProjectId @ $host '
      '(auth $authPort, firestore $firestorePort, storage $storagePort)',
    );
  }

  /// Firestore kalıcı önbelleğini açar (Q-12). Emülatör bağlamasından önce
  /// çağrılır; bağlama adresi bu ayarın üstüne yazar.
  @visibleForTesting
  static void applyFirestoreSettings(FirebaseFirestore firestore) {
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: firestoreCacheSizeBytes,
    );
  }

  /// Verilen üç SDK örneğini [host] üzerindeki emülatörlere bağlar
  /// ([authPort], [firestorePort], [storagePort]).
  @visibleForTesting
  static Future<void> bindEmulators({
    required String host,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  }) async {
    await auth.useAuthEmulator(host, authPort);
    firestore.useFirestoreEmulator(host, firestorePort);
    await storage.useStorageEmulator(host, storagePort);
  }
}
