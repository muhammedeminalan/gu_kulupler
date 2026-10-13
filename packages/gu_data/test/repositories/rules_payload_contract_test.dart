// T-12 · Repository ↔ Security Rules yük sözleşmesi (PLAN §10.4, §11.1;
// rules-spec §3.1, §3.2, §3.12; CLAUDE.md §9 "yazma yolu = Rules + testi").
//
// Gerçek `FirebaseUserRepository` / `FirebaseSettingsRepository`, SDK'ya
// giden her yazımı (işlem, yol, ham yük — `FieldValue` nöbetçileri dahil)
// kaydeden bir çifte karşı koşar; yakalanan yazımlar
// `firebase/test/contracts/repository_payloads.json` ile **birebir** aynı
// olmalıdır. Aynı dosyayı `firebase/test/rules/repository_payloads.test.js`
// emülatörde kurallar açıkken gönderir: repository'nin yazdığı her yük
// kurallardan geçer. Yük ya da beyaz liste tek başına değişirse iki testten
// biri kırılır.
//
// T-14: `UserRepository.updateAvatar` yazımları da sözleşmededir (profil
// yamasıyla aynı yazım; tamamlanmış profilde yalnızca `avatarPath` — W-57) ve
// AUT-05'in gerçek sırası (`aut05`: createProfile → tamamlama yaması →
// yamasız `updateAvatar`). Dosya adı sabit saat + sabit rastgele baytlarla
// üretilir.
//
// T-15: `t15.scenarios` — `FirebaseMembershipRepository` (M1–M4, M7, M8),
// `FirebaseReportRepository` ve `FirebaseBlockRepository`. Her senaryo kendi
// ön koşul belgeleriyle (`seed`) koşar; yakalanan **okumalar** (transaction
// içi dahil) ve yazımlar sözleşmeyle birebir olmalıdır: jest tarafı aynı
// okuma + yazımları emülatörde tek transaction olarak gönderir. Sayaç deltası
// `{"@increment": n}`, günlük belgesinin üretilen kimliği `@autoId` olarak
// yazılır.
//
// T-16: `MembershipRepository.updateApplicationNote` senaryosu aynı
// `t15.scenarios` listesindedir (üyelik + kulüp okunur, yalnızca
// `private/contact.note` yazılır — rules-spec §3.4 U(b)). Ekranların gerçek
// çağrıları da sözleşmededir: CLB-03 kulüp şikayeti
// (`ReportRepository.report · kulüp`, hedef = kulübün kendisi) ve SHT-07'nin
// üç `updateClubSettings` yazımı (tümünü sessize al / sessizi kaldır / tek
// tür) öykü adımlarında (`steps`).
//
// SDK sınıfları `@sealed` işaretlidir; test çifti bilerek uygular.
// ignore_for_file: subtype_of_sealed_class
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/fake_notification_dispatcher.dart';
import '../fakes/recording_storage_service.dart';
import '../helpers/repo_sources.dart';

const String _contractPath = 'firebase/test/contracts/repository_payloads.json';

/// Sözleşme dosyasındaki sunucu zamanı nöbetçisi.
const String _serverTimestamp = '@serverTimestamp';

/// Sözleşmedeki sayaç deltası anahtarı (`{"@increment": n}`).
const String _increment = '@increment';

/// Sözleşmede üretilen belge kimliğinin (`FirestoreService.newId`) yeri.
const String _autoId = '@autoId';

/// Ön koşul belgelerindeki göreli zaman nöbetçisinin öneki (`@daysAgo:N`).
const String _daysAgo = '@daysAgo:';

/// Repository'nin sayaçlara yazabildiği deltalar (CD-41: yalnızca ±1).
const List<int> _counterDeltas = [1, -1];

/// SDK'ya giden tek yazım.
typedef _Write = ({String op, String path, Object? data});

/// Yazımları [log]'a, okumaları [reads]'e kaydeden veritabanı; okumalar
/// [docs] içindeki belgeyi, yoksa "belge yok" döner.
final class _RecordingFirestore implements FirebaseFirestore {
  final List<_Write> log = [];

  /// Okunan belge yolları (transaction içi ve dışı), sırayla.
  final List<String> reads = [];

  /// Okumaların göreceği belgeler: yol → alanlar.
  final Map<String, Json> docs = {};

  /// `runTransaction` çağrı sayısı.
  int transactions = 0;

  @override
  CollectionReference<Json> collection(String collectionPath) =>
      _RecordingCollection(collectionPath, this);

  @override
  WriteBatch batch() => _RecordingBatch(log);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    transactions++;
    final transaction = _RecordingTransaction(this);
    final result = await transactionHandler(transaction);
    // Gövde hata vermeden bittiyse yazımlar tek seferde işlenir.
    log.addAll(transaction.pending);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingCollection implements CollectionReference<Json> {
  _RecordingCollection(this.path, this._db);

  @override
  final String path;
  final _RecordingFirestore _db;

  /// Kimlik verilmezse (`FirestoreService.newId`) sabit [_autoId] üretilir.
  @override
  DocumentReference<Json> doc([String? path]) =>
      _RecordingReference('${this.path}/${path ?? _autoId}', _db);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingReference implements DocumentReference<Json> {
  _RecordingReference(this.path, this._db);

  @override
  final String path;
  final _RecordingFirestore _db;

  @override
  String get id => path.split('/').last;

  @override
  Future<DocumentSnapshot<Json>> get([GetOptions? options]) async {
    _db.reads.add(path);
    return _StoredSnapshot(this, _db.docs[path]);
  }

  @override
  Future<void> set(Json data, [SetOptions? options]) async =>
      _db.log.add((op: 'set', path: path, data: data));

  @override
  Future<void> update(Map<Object, Object?> data) async =>
      _db.log.add((op: 'update', path: path, data: data));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Okumaları veritabanının [_RecordingFirestore.reads] günlüğüne yazan,
/// yazımları [pending]'de biriktiren transaction.
final class _RecordingTransaction implements Transaction {
  _RecordingTransaction(this._db);

  final _RecordingFirestore _db;

  /// Kuyruğa giren yazımlar, sırayla.
  final List<_Write> pending = [];

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    final path = documentReference.path;
    _db.reads.add(path);
    return _StoredSnapshot(_RecordingReference(path, _db), _db.docs[path])
        as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    pending.add((op: 'set', path: documentReference.path, data: data));
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    pending.add((op: 'update', path: documentReference.path, data: data));
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [_data] alanlarını taşıyan belge görüntüsü; `null` → belge yok.
final class _StoredSnapshot implements DocumentSnapshot<Json> {
  _StoredSnapshot(this.reference, this._data);

  @override
  final DocumentReference<Json> reference;
  final Json? _data;

  @override
  bool get exists => _data != null;

  @override
  String get id => reference.id;

  @override
  Json? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Yazımlarını commit anında [_log]'a aktaran batch.
final class _RecordingBatch implements WriteBatch {
  _RecordingBatch(this._log);

  final List<_Write> _log;
  final List<_Write> _pending = [];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      _pending.add((op: 'set', path: document.path, data: data));

  @override
  void update<T>(DocumentReference<T> document, T data) =>
      _pending.add((op: 'update', path: document.path, data: data));

  @override
  Future<void> commit() async => _log.addAll(_pending);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ham yükü sözleşme dosyasının biçimine çevirir: sunucu zamanı nöbetçisi
/// [_serverTimestamp], sayaç deltası `{"@increment": n}` olur; başka her
/// `FieldValue` hatadır (sözleşmede yok).
Object? _normalize(Object? value) => switch (value) {
  final FieldValue field when field == FieldValue.serverTimestamp() =>
    _serverTimestamp,
  final FieldValue field => {_increment: _deltaOf(field)},
  final Map<Object?, Object?> map => {
    for (final entry in map.entries) entry.key: _normalize(entry.value),
  },
  final List<Object?> list => [for (final item in list) _normalize(item)],
  _ => value,
};

/// [field] nöbetçisinin sayaç deltası; ±1 değilse hata (CD-41).
int _deltaOf(FieldValue field) => _counterDeltas.firstWhere(
  (delta) => field == FieldValue.increment(delta),
  orElse: () => throw StateError('beklenmeyen FieldValue: $field'),
);

List<Object?> _normalized(List<_Write> writes) => [
  for (final write in writes)
    {'op': write.op, 'path': write.path, 'data': _normalize(write.data)},
];

/// `updateAvatar` dosya adının girdileri (sözleşmedeki yol bunlardan çıkar).
final DateTime _uploadedAt = DateTime.utc(2026, 10, 8, 20, 15, 2);
const List<int> _randomBytes = [0x0a, 0x1b, 0x2c, 0x3d, 0x4e, 0x5f, 0x60, 0x71];
final Uint8List _image = Uint8List.fromList(const [0xff, 0xd8, 0xff, 0xe0]);

/// `updateAvatar`'ın ön koşul okuması (W-57) için tamamlanmış profil belgesi:
/// yamasız çağrı yalnızca ilgi alanı olan profilde yükleme yapar.
void _seedCompleteProfile(_RecordingFirestore db, String uid) {
  db.docs['users/$uid'] = const UserModel(
    name: 'Ayşe Işık',
    nameLower: 'ayşe ışık',
    avatarSeed: 'u',
    department: 'd02',
    year: YearLevel.second,
    interests: ['i01', 'i05'],
    profileComplete: true,
  ).toJson();
}

/// T-15 senaryolarının "şimdi"si (`@daysAgo:N` bu ana göre çözülür).
final DateTime _scenarioNow = DateTime.utc(2026, 10, 13, 9);

/// Ön koşul belgesindeki nöbetçileri SDK değerine çevirir: sunucu zamanı →
/// [_scenarioNow], `@daysAgo:N` → N gün öncesi (negatif = sonrası).
Object? _seedValue(Object? value) => switch (value) {
  _serverTimestamp => Timestamp.fromDate(_scenarioNow),
  final String text when text.startsWith(_daysAgo) => Timestamp.fromDate(
    _scenarioNow.subtract(
      Duration(days: int.parse(text.substring(_daysAgo.length))),
    ),
  ),
  final Map<Object?, Object?> map => <String, Object?>{
    for (final entry in map.entries)
      entry.key! as String: _seedValue(entry.value),
  },
  final List<Object?> list => [for (final item in list) _seedValue(item)],
  _ => value,
};

/// `{"$fixture": ad, …}` girdisini `fixtures[ad]` + üzerine yazılan alanlar
/// olarak açar ve nöbetçilerini çözer.
Json _seedDoc(Map<String, Object?> fixtures, Object? entry) {
  final fields = {...entry! as Map<String, Object?>};
  final fixture = fields.remove(r'$fixture') as String?;
  return _seedValue({
        if (fixture != null) ...fixtures[fixture]! as Map<String, Object?>,
        ...fields,
      })!
      as Json;
}

void main() {
  final contract = readRepoJson(_contractPath);
  final uid = contract['uid']! as String;
  final email = contract['email']! as String;
  final clubId = contract['clubId']! as String;
  final steps = [
    ...(contract['steps']! as List<Object?>).cast<Map<String, Object?>>(),
    ...(contract['standalone']! as List<Object?>).cast<Map<String, Object?>>(),
  ];

  late _RecordingFirestore db;
  late RecordingStorageService storage;
  late UserRepository users;
  late SettingsRepository settings;

  /// Sözleşmedeki her çağrının gerçek repository karşılığı.
  late final calls =
      <String, Future<FirebaseResult<Object?, Object>> Function()>{
        'UserRepository.createProfile': () => users.createProfile(
          uid: uid,
          email: email,
          name: 'Ayşe Işık',
          nameLower: 'ayşe ışık',
          avatarSeed: uid,
        ),
        // AUT-05'in gerçek yazımları (SetupProfileViewModel.submit; W-57):
        // tamamlama yaması → yamasız `updateAvatar`. Aynı yama kök
        // `test/flows/auth_flow_test.dart` içinde ViewModel'den yakalanır.
        'UserRepository.updateProfile · AUT-05 tamamlama '
            '(SetupProfileViewModel.submit)': () => users.updateProfile(
          uid,
          const UserProfilePatch(
            department: 'd02',
            year: YearLevel.second,
            interests: ['i01', 'i05'],
            profileComplete: true,
          ),
        ),
        'UserRepository.updateAvatar · AUT-05 (tamamlama yamasından sonra)':
            () {
              _seedCompleteProfile(db, uid);
              return users.updateAvatar(
                uid,
                bytes: _image,
                contentType: 'image/jpeg',
              );
            },
        'UserRepository.updateProfile · tam profil yaması': () =>
            users.updateProfile(
              uid,
              const UserProfilePatch(
                name: 'Ayşe Işık',
                nameLower: 'ayşe ışık',
                department: 'd02',
                year: YearLevel.second,
                interests: ['i01', 'i05'],
                profileComplete: true,
              ),
            ),
        'UserRepository.updateAvatar · profil yamasıyla aynı yazım': () =>
            users.updateAvatar(
              uid,
              bytes: _image,
              contentType: 'image/jpeg',
              profile: const UserProfilePatch(
                name: 'Ayşe Işık',
                nameLower: 'ayşe ışık',
                department: 'd02',
                year: YearLevel.second,
                interests: ['i01', 'i05'],
                profileComplete: true,
              ),
            ),
        'UserRepository.updateAvatar · tamamlanmış profil (PRF-02)': () {
          _seedCompleteProfile(db, uid);
          return users.updateAvatar(
            uid,
            bytes: _image,
            contentType: 'image/png',
          );
        },
        'UserRepository.updateProfile · profil fotoğrafı': () =>
            users.updateProfile(
              uid,
              UserProfilePatch(
                avatarSeed: '$uid-2',
                avatarPath: 'users/$uid/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
              ),
            ),
        'UserRepository.updateProfile · fotoğrafı kaldır (SHT-16)': () => users
            .updateProfile(uid, const UserProfilePatch(clearAvatarPath: true)),
        'UserRepository.updateProfile · profil düzenleme (PRF-02)': () =>
            users.updateProfile(
              uid,
              const UserProfilePatch(
                name: 'Ayşe Işık Demir',
                nameLower: 'ayşe ışık demir',
                department: 'd03',
                year: YearLevel.master,
                interests: ['i02'],
                bio: 'Merhaba.',
              ),
            ),
        'UserRepository.touchLastLogin': () => users.touchLastLogin(uid),
        'SettingsRepository.updateSettings': () => settings.updateSettings(
          uid,
          const UserSettingsPatch(
            announcements: false,
            eventReminders: false,
            newEvents: false,
            applicationResults: false,
            management: false,
            system: false,
            reminderTime: ReminderOption.oneDay,
            quiet: true,
            quietFrom: '23:30',
            quietTo: '07:15',
          ),
        ),
        'SettingsRepository.updateClubSettings': () =>
            settings.updateClubSettings(
              uid,
              clubId,
              const ClubNotificationPrefsModel(events: false, muted: true),
            ),
        // T-16 · SHT-07'nin gerçek yazımları
        // (`ClubNotificationPrefsViewModel.toggle`): tümünü sessize al →
        // üç tür kapanır; sessizi kaldır → üçü açılır; tek tür.
        'SettingsRepository.updateClubSettings · SHT-07 tümünü sessize al':
            () => settings.updateClubSettings(
              uid,
              clubId,
              const ClubNotificationPrefsModel(
                announcements: false,
                events: false,
                posts: false,
                muted: true,
              ),
            ),
        'SettingsRepository.updateClubSettings · SHT-07 sessizi kaldır': () =>
            settings.updateClubSettings(
              uid,
              clubId,
              const ClubNotificationPrefsModel(),
            ),
        'SettingsRepository.updateClubSettings · SHT-07 tek tür '
            '(duyurular kapalı)': () => settings.updateClubSettings(
          uid,
          clubId,
          const ClubNotificationPrefsModel(announcements: false),
        ),
        // Kayıt tutan çiftte belge yoktur: `getSettings` varsayılanı yazar.
        'SettingsRepository.getSettings · belge yok': () =>
            settings.getSettings(uid),
      };

  setUp(() {
    db = _RecordingFirestore();
    storage = RecordingStorageService();
    final service = FirebaseFirestoreService(db);
    users = FirebaseUserRepository(
      service,
      storage,
      FakeAppClock(_uploadedAt),
      SequenceRandom(_randomBytes),
    );
    settings = FirebaseSettingsRepository(service);
  });

  group('T-12 · Rules yük sözleşmesi', () {
    test('sözleşmedeki her adımın repository karşılığı var; fazlası yok', () {
      expect(steps.map((step) => step['call']), unorderedEquals(calls.keys));
      expect(contract['serverTimestamp'], _serverTimestamp);
    });

    for (final step in steps) {
      final call = step['call']! as String;
      test("$call — SDK'ya giden yazımlar sözleşmeyle birebir", () async {
        final result = await calls[call]!();

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(_normalized(db.log), step['writes']);
      });
    }

    test('aut05: AUT-05 sırasındaki her çağrı sözleşmede bir adımdır ve '
        'sırası createProfile → updateProfile → updateAvatar', () {
      final sequence = (contract['aut05']! as List<Object?>).cast<String>();
      final story = [
        for (final step in contract['steps']! as List<Object?>)
          (step! as Map<String, Object?>)['call']! as String,
      ];

      expect(sequence, hasLength(3));
      expect(sequence[0], 'UserRepository.createProfile');
      expect(sequence[1], startsWith('UserRepository.updateProfile'));
      expect(sequence[2], startsWith('UserRepository.updateAvatar'));
      // Öyküde aynı sırayla ve art arda yer alır (jest yeniden oynatması).
      expect(story.sublist(0, 3), sequence);
    });

    test("updateAvatar: Firestore'a yazılan avatarPath, Storage'a yüklenen "
        'dosyanın yoludur ve users/{uid}/ altındadır', () async {
      for (final step in steps) {
        final call = step['call']! as String;
        if (!call.startsWith('UserRepository.updateAvatar')) continue;
        db.log.clear();
        storage.uploads.clear();

        await calls[call]!();

        final written = (db.log.single.data! as Map)['avatarPath']! as String;
        expect(storage.uploads.single.path, written, reason: call);
        expect(StoragePaths.isUserAvatar(written, uid), isTrue, reason: call);
      }
    });
  });

  group('T-15 · Rules yük sözleşmesi (kulüp / üyelik / şikayet / engel)', () {
    final t15 = contract['t15']! as Map<String, Object?>;
    final fixtures = t15['fixtures']! as Map<String, Object?>;
    final scenarios = (t15['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>();
    // Başvuran profili sözleşmedeki kullanıcı belgesinden gelir: Rules
    // `applicant` anlık görüntüsünü bu belgeyle karşılaştırır.
    final student = UserModel.fromJson(
      _seedDoc(fixtures, const {r'$fixture': 'user'}),
      id: uid,
    );
    const application = 'Kulübe katılmak istiyorum.';
    const reapplication = 'Yeniden başvuruyorum.';
    const edited = 'Güncel not.';
    const blocked = 'u_member';
    const ReportTarget post = (
      type: ReportTargetType.post,
      id: 'p01',
      clubId: 'c01',
    );

    late MembershipRepository memberships;
    late ReportRepository reports;
    late BlockRepository blocks;

    Future<FirestoreResult<MembershipModel>> apply(String note) =>
        memberships.apply(
          clubId: clubId,
          applicant: student,
          email: email,
          note: note,
        );
    Future<FirestoreResult<MembershipModel>> join() => memberships.joinInstant(
      clubId: clubId,
      applicant: student,
      email: email,
    );

    /// Sözleşmedeki her senaryonun gerçek repository karşılığı.
    late final calls =
        <String, Future<FirebaseResult<Object?, Object>> Function()>{
          'MembershipRepository.apply · M1 notlu (requireNote kulübü)': () =>
              apply(application),
          'MembershipRepository.apply · M1 notsuz': () => apply(''),
          'MembershipRepository.joinInstant · M2': join,
          'MembershipRepository.apply · M3 yeniden başvuru '
              '(cancelled → pending)': () =>
              apply(reapplication),
          'MembershipRepository.joinInstant · M3 yeniden katılım '
                  '(left → active)':
              join,
          'MembershipRepository.apply · M4 '
              '(rejected, bekleme süresi doldu → pending)': () =>
              apply(reapplication),
          'MembershipRepository.apply · M3 iletişim belgesi yok': () =>
              apply(reapplication),
          'MembershipRepository.cancelApplication · M7': () =>
              memberships.cancelApplication(clubId: clubId, userId: uid),
          'MembershipRepository.updateApplicationNote · not düzenleme '
              '(pending)': () => memberships.updateApplicationNote(
            clubId: clubId,
            userId: uid,
            note: edited,
          ),
          'MembershipRepository.leave · M8': () =>
              memberships.leave(clubId: clubId, userId: uid),
          'MembershipRepository.readContact · üyelik yok': () =>
              memberships.readContact(clubId, uid),
          'ReportRepository.report · gönderi': () => reports.report(
            reporterId: uid,
            target: post,
            reason: ReportReason.spam,
          ),
          'ReportRepository.report · kullanıcı': () => reports.report(
            reporterId: uid,
            target: (type: ReportTargetType.user, id: blocked, clubId: null),
            reason: ReportReason.harassment,
            note: 'Rahatsız edici mesajlar.',
          ),
          // T-16 · CLB-03 "Bu kulübü şikayet et" (SHT-10, neden "Diğer").
          'ReportRepository.report · kulüp (CLB-03 → SHT-10)': () =>
              reports.report(
                reporterId: uid,
                target: (
                  type: ReportTargetType.club,
                  id: clubId,
                  clubId: clubId,
                ),
                reason: ReportReason.other,
                note: 'Kulüp sayfasındaki bilgiler yanıltıcı.',
              ),
          'ReportRepository.hasReported · şikayet yok': () =>
              reports.hasReported(reporterId: uid, target: post),
          'BlockRepository.block · yeni engel': () =>
              blocks.block(blockerId: uid, blockedId: blocked),
          'BlockRepository.softDeleteBlock': () =>
              blocks.softDeleteBlock(blockerId: uid, blockedId: blocked),
          'BlockRepository.block · kaldırılmış engeli geri yükler': () =>
              blocks.block(blockerId: uid, blockedId: blocked),
          'BlockRepository.restoreBlock': () =>
              blocks.restoreBlock(blockerId: uid, blockedId: blocked),
        };

    setUp(() {
      final service = FirebaseFirestoreService(db);
      memberships = FirebaseMembershipRepository(
        service,
        FirebaseActivityRepository(service),
        FakeNotificationDispatcher(),
        FakeAppClock(_scenarioNow),
      );
      reports = FirebaseReportRepository(service);
      blocks = FirebaseBlockRepository(service);
    });

    test('sözleşmedeki her senaryonun repository karşılığı var; fazlası '
        'yok', () {
      expect(
        scenarios.map((scenario) => scenario['call']),
        unorderedEquals(calls.keys),
      );
      expect(t15['autoId'], _autoId);
      expect(t15['increment'], _increment);
      expect(student.profileComplete, isTrue);
    });

    for (final scenario in scenarios) {
      final call = scenario['call']! as String;
      test('$call — okumalar ve yazımlar sözleşmeyle birebir', () async {
        final seed = scenario['seed']! as Map<String, Object?>;
        for (final MapEntry(key: path, value: entry) in seed.entries) {
          db.docs[path] = _seedDoc(fixtures, entry);
        }

        final result = await calls[call]!();

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(db.reads, scenario['reads']);
        expect(_normalized(db.log), scenario['writes']);
        // Çok belgeli geçişler tek transaction'dır (üyelik + sayaç + günlük).
        expect(db.transactions, scenario['tx'] == true ? 1 : 0);
      });
    }

    test('bozuk varyantlar yalnızca var olan yazım sıralarına ve ön koşul '
        'belgelerine dokunur', () {
      for (final scenario in scenarios) {
        final writes = scenario['writes']! as List<Object?>;
        final denied = (scenario['denied'] as List<Object?>? ?? const [])
            .cast<Map<String, Object?>>();
        for (final variant in denied) {
          final indexes = [
            ...(variant['without'] as List<Object?>? ?? const []).cast<int>(),
            ...(variant['patch'] as Map<String, Object?>? ?? const {}).keys.map(
              int.parse,
            ),
          ];
          final reason = '${scenario['call']} · ${variant['name']}';
          expect(
            indexes,
            everyElement(lessThan(writes.length)),
            reason: reason,
          );
          expect(
            variant.keys.toSet().difference({
              'name',
              'without',
              'patch',
              'seed',
              'role',
            }),
            isEmpty,
            reason: reason,
          );
          expect(variant.length, greaterThan(1), reason: reason);
        }
      }
    });
  });
}
