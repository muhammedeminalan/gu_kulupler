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
// T-19: `t19.scenarios` — `FirebasePostRepository`, `FirebaseCommentRepository`,
// `FirebaseSavedPostRepository`, `FirebaseAnnouncementCounterRepository`. Her
// senaryo kendi bağlamıyla koşar (`role`: üye, yönetim, danışman, süper admin
// — uid `t19.actors` içinde). Ek nöbetçiler: `{"@arrayUnion": [uid]}` /
// `{"@arrayRemove": [uid]}` (beğeni), `@daysAhead:N` (anket bitişi: senaryo
// saatinden N gün sonrası), `@yyyyMMdd` / `@yyyy-MM-dd` (duyuru sayacının
// Istanbul günü: Dart tarafında senaryo saatinin, jest tarafında emülatörün
// günü) ve `merge: true` (`set(merge)` — sayaç artışı).
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

/// Sözleşmedeki dizi işlemi anahtarları (`{"@arrayUnion": [uid]}`).
const String _arrayUnion = '@arrayUnion';
const String _arrayRemove = '@arrayRemove';

/// Sözleşmede "senaryo saatinden N gün sonrası" nöbetçisinin öneki.
const String _daysAhead = '@daysAhead:';

/// Sözleşmede duyuru sayacının Istanbul günü: belge kimliği eki ve `day`.
const String _dayKeyToken = '@yyyyMMdd';
const String _dayToken = '@yyyy-MM-dd';

/// Repository'nin sayaçlara yazabildiği deltalar (CD-41: yalnızca ±1).
const List<int> _counterDeltas = [1, -1];

/// SDK'ya giden tek yazım; `merge` yalnızca `set(merge: true)` için `true`.
typedef _Write = ({String op, String path, Object? data, bool merge});

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
  Future<void> set(Json data, [SetOptions? options]) async => _db.log.add((
    op: 'set',
    path: path,
    data: data,
    merge: options?.merge ?? false,
  ));

  @override
  Future<void> update(Map<Object, Object?> data) async =>
      _db.log.add((op: 'update', path: path, data: data, merge: false));

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
    pending.add((
      op: 'set',
      path: documentReference.path,
      data: data,
      merge: options?.merge ?? false,
    ));
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    pending.add((
      op: 'update',
      path: documentReference.path,
      data: data,
      merge: false,
    ));
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
      _pending.add((
        op: 'set',
        path: document.path,
        data: data,
        merge: options?.merge ?? false,
      ));

  @override
  void update<T>(DocumentReference<T> document, T data) => _pending.add((
    op: 'update',
    path: document.path,
    data: data,
    merge: false,
  ));

  @override
  Future<void> commit() async => _log.addAll(_pending);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ham yükü sözleşme dosyasının biçimine çevirir: sunucu zamanı nöbetçisi
/// [_serverTimestamp], sayaç deltası `{"@increment": n}`, dizi işlemi
/// `{"@arrayUnion": [uid]}` / `{"@arrayRemove": [uid]}` ([uids] içindeki tek
/// kimlikle), ileri tarihli an `@daysAhead:N` olur; başka her `FieldValue`
/// hatadır (sözleşmede yok).
Object? _normalize(Object? value, {List<String> uids = const []}) =>
    switch (value) {
      final FieldValue field when field == FieldValue.serverTimestamp() =>
        _serverTimestamp,
      final FieldValue field => _sentinelOf(field, uids),
      final Timestamp instant => _aheadOf(instant),
      final Map<Object?, Object?> map => {
        for (final entry in map.entries)
          entry.key: _normalize(entry.value, uids: uids),
      },
      final List<Object?> list => [
        for (final item in list) _normalize(item, uids: uids),
      ],
      _ => value,
    };

/// [field] nöbetçisinin sözleşme karşılığı: sayaç deltası (yalnızca ±1 —
/// CD-41) ya da [uids] içindeki tek kimliği ekleyen / çıkaran dizi işlemi.
Map<String, Object?> _sentinelOf(FieldValue field, List<String> uids) {
  for (final delta in _counterDeltas) {
    if (field == FieldValue.increment(delta)) return {_increment: delta};
  }
  for (final uid in uids) {
    if (field == FieldValue.arrayUnion([uid])) {
      return {
        _arrayUnion: [uid],
      };
    }
    if (field == FieldValue.arrayRemove([uid])) {
      return {
        _arrayRemove: [uid],
      };
    }
  }
  throw StateError('beklenmeyen FieldValue: $field');
}

/// [instant] anının senaryo saatine ([_scenarioNow]) göre `@daysAhead:N`
/// karşılığı; tam gün değilse hata (repository yalnızca gün ekler).
String _aheadOf(Timestamp instant) {
  final ahead = instant.toDate().toUtc().difference(_scenarioNow);
  if (ahead != Duration(days: ahead.inDays)) {
    throw StateError('tam gün değil: ${instant.toDate().toUtc()}');
  }
  return '$_daysAhead${ahead.inDays}';
}

List<Object?> _normalized(
  List<_Write> writes, {
  List<String> uids = const [],
}) => [
  for (final write in writes)
    {
      'op': write.op,
      'path': write.path,
      'data': _normalize(write.data, uids: uids),
      if (write.merge) 'merge': true,
    },
];

/// [value] içindeki her dizgiyi (iç içe map / liste dahil; anahtarlar hariç)
/// [convert] ile değiştirir.
Object? _mapStrings(Object? value, String Function(String text) convert) =>
    switch (value) {
      final String text => convert(text),
      final Map<Object?, Object?> map => <String, Object?>{
        for (final entry in map.entries)
          entry.key! as String: _mapStrings(entry.value, convert),
      },
      final List<Object?> list => [
        for (final item in list) _mapStrings(item, convert),
      ],
      _ => value,
    };

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

/// Her senaryonun bozuk varyantları (`denied`) yalnızca var olan yazım
/// sıralarına dokunur, bilinen anahtarları taşır ve adından başka en az bir
/// değişiklik içerir.
void _expectWellFormedVariants(List<Map<String, Object?>> scenarios) {
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
      expect(indexes, everyElement(lessThan(writes.length)), reason: reason);
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
      _expectWellFormedVariants(scenarios);
    });
  });

  group('T-19 · Rules yük sözleşmesi (gönderi / yorum / oy / kayıt / sayaç)', () {
    final t19 = contract['t19']! as Map<String, Object?>;
    final fixtures = t19['fixtures']! as Map<String, Object?>;
    final actors = (t19['actors']! as Map<String, Object?>)
        .cast<String, String>();
    final scenarios = (t19['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final clock = FakeAppClock(_scenarioNow);
    // Sayaç günü: senaryo saatinin Istanbul günü sözleşmede yer tutucudur
    // (jest emülatörün gününü koyar).
    final dayKey = clock.istanbulDayKey(_scenarioNow);
    final day = clock.istanbulDay(_scenarioNow);
    String withDay(String text) =>
        text.replaceAll(_dayKeyToken, dayKey).replaceAll(_dayToken, day);
    String dayless(String text) =>
        text.replaceAll(dayKey, _dayKeyToken).replaceAll(day, _dayToken);

    const postId = 'p01';
    const newPostId = 'p_new';
    const commentId = 'cm01';
    PostImageModel imageOf(String id) => PostImageModel(
      path: 'posts/$id/20261008T201502Z_0a1b2c3d4e5f6071.jpg',
      w: 1200,
      h: 800,
    );

    late PostRepository posts;
    late CommentRepository comments;
    late SavedPostRepository saved;
    late AnnouncementCounterRepository counters;

    Future<FirestoreResult<PostModel>> publish(String uid, PostDraft draft) =>
        posts.create(draft, authorId: uid, clubId: clubId, postId: newPostId);
    const pushed = PostDraft(
      type: PostType.announcement,
      title: 'Genel kurul',
      text: 'Genel kurul cuma günü 14.00’te.',
      pushSent: true,
    );

    /// Sözleşmedeki her senaryonun gerçek repository karşılığı; argüman
    /// senaryonun `role` bağlamının uid'idir.
    late final calls =
        <String, Future<FirebaseResult<Object?, Object>> Function(String uid)>{
          'PostRepository.create · gönderi (görselli)': (uid) => publish(
            uid,
            PostDraft(
              type: PostType.post,
              text: 'Yeni gönderi.',
              images: [imageOf(newPostId)],
            ),
          ),
          'PostRepository.create · bildirimsiz duyuru': (uid) => publish(
            uid,
            const PostDraft(
              type: PostType.announcement,
              title: 'Toplantı',
              text: 'Haftalık toplantı salı günü.',
            ),
          ),
          'PostRepository.create · bildirimli duyuru (günün ilki)': (uid) =>
              publish(uid, pushed),
          'PostRepository.create · bildirimli duyuru (günün ikincisi)': (uid) =>
              publish(uid, pushed),
          'PostRepository.create · anket': (uid) => publish(
            uid,
            const PostDraft(
              type: PostType.poll,
              text: 'Hangi gün buluşalım?',
              poll: PollDraft(
                options: ['Cuma', 'Cumartesi', 'Pazar'],
                durationDays: 3,
              ),
            ),
          ),
          'PostRepository.update · metin + görsel': (uid) => posts.update(
            postId,
            PostEditPatch(
              text: 'Düzenlenmiş metin.',
              images: [imageOf(postId)],
            ),
            authorId: uid,
          ),
          'PostRepository.update · duyuru başlığı': (uid) => posts.update(
            postId,
            const PostEditPatch(title: 'Yeni başlık'),
            authorId: uid,
          ),
          'PostRepository.like': (uid) => posts.like(postId, uid: uid),
          'PostRepository.unlike': (uid) => posts.unlike(postId, uid: uid),
          'PostRepository.vote': (uid) =>
              posts.vote(postId, uid: uid, optionId: 'o2'),
          'PostRepository.myVote · oy yok': (uid) =>
              posts.myVote(postId, uid: uid),
          'PostRepository.pin · ilk sabit': (_) =>
              posts.pin(postId, clubId: clubId),
          'PostRepository.pin · eski sabit değişir': (_) =>
              posts.pin(postId, clubId: clubId),
          'PostRepository.unpin': (_) => posts.unpin(postId, clubId: clubId),
          'PostRepository.softDeletePost · başkasının gönderisi (sabit değil)':
              (uid) =>
                  posts.softDeletePost(postId, actorId: uid, clubId: clubId),
          'PostRepository.softDeletePost · sabit gönderi': (uid) =>
              posts.softDeletePost(postId, actorId: uid, clubId: clubId),
          'PostRepository.softDeletePost · süper admin (sabit gönderi)':
              (uid) =>
                  posts.softDeletePost(postId, actorId: uid, clubId: clubId),
          'PostRepository.restorePost · silen yönetici': (_) =>
              posts.restorePost(postId),
          'PostRepository.restorePost · süper admin': (_) =>
              posts.restorePost(postId),
          'PostRepository.hide': (uid) => posts.hide(postId, actorId: uid),
          'PostRepository.unhide': (_) => posts.unhide(postId),
          'PostRepository.getPost': (_) => posts.getPost(postId),
          'CommentRepository.add': (uid) => comments.add(
            postId: postId,
            clubId: clubId,
            authorId: uid,
            text: 'Yeni yorum.',
          ),
          'CommentRepository.softDeleteComment · yazar': (uid) => comments
              .softDeleteComment(commentId, postId: postId, actorId: uid),
          'CommentRepository.softDeleteComment · yönetici (başkasının yorumu)':
              (uid) => comments.softDeleteComment(
                commentId,
                postId: postId,
                actorId: uid,
              ),
          'CommentRepository.softDeleteComment · süper admin': (uid) => comments
              .softDeleteComment(commentId, postId: postId, actorId: uid),
          'CommentRepository.restoreComment': (_) =>
              comments.restoreComment(commentId, postId: postId),
          'CommentRepository.hide': (uid) =>
              comments.hide(commentId, actorId: uid),
          'SavedPostRepository.save · yeni kayıt': (uid) =>
              saved.save(userId: uid, postId: postId, clubId: clubId),
          'SavedPostRepository.save · danışman': (uid) =>
              saved.save(userId: uid, postId: postId, clubId: clubId),
          'SavedPostRepository.save · kaldırılmış kaydı geri yükler': (uid) =>
              saved.save(userId: uid, postId: postId, clubId: clubId),
          'SavedPostRepository.softDeleteSaved': (uid) =>
              saved.softDeleteSaved(userId: uid, postId: postId),
          'SavedPostRepository.restoreSaved': (uid) =>
              saved.restoreSaved(userId: uid, postId: postId),
          'SavedPostRepository.isSaved · kayıt yok': (uid) =>
              saved.isSaved(userId: uid, postId: postId),
          'AnnouncementCounterRepository.getToday · sayaç yok': (_) =>
              counters.getToday(clubId),
          'AnnouncementCounterRepository.getToday · sayaç var': (_) =>
              counters.getToday(clubId),
        };

    setUp(() {
      final service = FirebaseFirestoreService(db);
      final counterRepository = FirebaseAnnouncementCounterRepository(
        service,
        clock,
      );
      counters = counterRepository;
      posts = FirebasePostRepository(
        service,
        storage,
        FirebaseActivityRepository(service),
        counterRepository,
        clock,
        SequenceRandom(_randomBytes),
      );
      comments = FirebaseCommentRepository(service, clock);
      saved = FirebaseSavedPostRepository(service);
    });

    test('sözleşmedeki her senaryonun repository karşılığı var; fazlası '
        'yok', () {
      expect(
        scenarios.map((scenario) => scenario['call']),
        unorderedEquals(calls.keys),
      );
      expect(t19['autoId'], _autoId);
      expect(t19['increment'], _increment);
      expect(t19['arrayUnion'], _arrayUnion);
      expect(t19['arrayRemove'], _arrayRemove);
      expect(t19['daysAhead'], _daysAhead);
      expect(t19['dayKey'], _dayKeyToken);
      expect(t19['day'], _dayToken);
      // Her senaryonun bağlamı tanımlıdır.
      expect(
        scenarios.map((scenario) => scenario['role']),
        everyElement(isIn(actors.keys)),
      );
    });

    test('her yazma metodu en az bir senaryoda: PLAN §10.4 T-19 yazma '
        'yüzeyi', () {
      final covered = {
        for (final scenario in scenarios)
          if ((scenario['writes']! as List<Object?>).isNotEmpty)
            (scenario['call']! as String).split(' · ').first,
      };

      expect(covered, {
        'PostRepository.create',
        'PostRepository.update',
        'PostRepository.like',
        'PostRepository.unlike',
        'PostRepository.vote',
        'PostRepository.pin',
        'PostRepository.unpin',
        'PostRepository.softDeletePost',
        'PostRepository.restorePost',
        'PostRepository.hide',
        'PostRepository.unhide',
        'CommentRepository.add',
        'CommentRepository.softDeleteComment',
        'CommentRepository.restoreComment',
        'CommentRepository.hide',
        'SavedPostRepository.save',
        'SavedPostRepository.softDeleteSaved',
        'SavedPostRepository.restoreSaved',
      });
    });

    for (final scenario in scenarios) {
      final call = scenario['call']! as String;
      test('$call — okumalar ve yazımlar sözleşmeyle birebir', () async {
        final seed = scenario['seed']! as Map<String, Object?>;
        for (final MapEntry(key: path, value: entry) in seed.entries) {
          db.docs[withDay(path)] = _seedDoc(
            fixtures,
            _mapStrings(entry, withDay),
          );
        }
        final uid = actors[scenario['role']]!;

        final result = await calls[call]!(uid);

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(db.reads.map(dayless), scenario['reads']);
        expect(
          _mapStrings(_normalized(db.log, uids: [uid]), dayless),
          scenario['writes'],
        );
        // Birden çok belgeyi okuyup yazan yollar tek transaction'dır.
        expect(db.transactions, scenario['tx'] == true ? 1 : 0);
      });
    }

    test('bozuk varyantlar yalnızca var olan yazım sıralarına dokunur', () {
      _expectWellFormedVariants(scenarios);
    });
  });
}
