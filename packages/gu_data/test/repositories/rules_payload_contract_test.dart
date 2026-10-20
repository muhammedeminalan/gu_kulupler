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
// T-22: `t22.scenarios` — `FirebaseEventRepository` ve
// `FirebaseRsvpRepository` (`docs/plans/T-22.md §6`). Biçim `t19` ile
// aynıdır; ek olarak `upload` (kapak: Storage yolu + `customMetadata`, gerçek
// `StorageService` çağrısı) ve `@daysAhead:N` etkinlik zamanlarında (senaryo
// saatinden tam gün). Yeni etkinliğin kimliği `@autoId`'dir (`newId`); bilet
// kodu sıralı `FakeTicketCodeGenerator`'dan gelir.
//
// T-30: `t30.scenarios` — yönetici geçişleri (`FirebaseMembershipRepository`
// M5 / M6 / M9–M12), `FirebaseManagementRepository.updateClubSettings`,
// `FirebaseAttendanceRepository` (yoklama, terfi). Gerçek
// `ClientFanOutDispatcher` + `FirebaseNotificationRepository`: kritik
// bildirim geçişle aynı transaction'dadır (W-83). Sayaç işaretçisi yalnızca
// yan belgededir (`clubs|events/{id}/private/counter` — W-64).
//
// T-36: `t36.scenarios` — `FirebaseManagementRepository.updateClubMedia`
// (kulüp logosu / kapağı): ön okuma, sırayla Storage yüklemeleri (`uploads`:
// yol, tür, `customMetadata`), sonra kulüp + `settings_changed` günlüğü tek
// batch. Dosya adları sabit saat + 16 sabit rastgele bayttan (logo ilk 8,
// kapak sonraki 8).
//
// T-28: `t28.scenarios` — `FirebaseSupportRepository.createTicket` (eksiz /
// ekli). Belge kimliği talep numarasıdır; ek yüklemesi (`upload`) yazımdan
// öncedir.
//
// SDK sınıfları `@sealed` işaretlidir; test çifti bilerek uygular.
// ignore_for_file: subtype_of_sealed_class
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/fake_notification_dispatcher.dart';
import '../fakes/fake_ticket_code_generator.dart';
import '../fakes/recording_storage_service.dart';
import '../fakes/scripted_auth_service.dart';
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

  /// Her commit'in (batch, transaction ya da tekil yazım) yazım sayısı,
  /// sırayla — sözleşmedeki `batches` gruplarıyla karşılaştırılır (T-25).
  final List<int> commits = [];

  /// T-37 · koşulan koleksiyon sorguları (`{collection, where, limit}`),
  /// sırayla — sözleşmedeki `queries` ile karşılaştırılır.
  final List<Map<String, Object?>> queries = [];

  @override
  CollectionReference<Json> collection(String collectionPath) =>
      _RecordingCollection(collectionPath, this);

  @override
  WriteBatch batch() => _RecordingBatch(log, commits);

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
    if (transaction.pending.isNotEmpty) commits.add(transaction.pending.length);
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
  Query<Json> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _RecordingQuery(path, _db, const [], null).where(
    field,
    isEqualTo: isEqualTo,
    isNotEqualTo: isNotEqualTo,
    isLessThan: isLessThan,
    isLessThanOrEqualTo: isLessThanOrEqualTo,
    isGreaterThan: isGreaterThan,
    isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
    arrayContains: arrayContains,
    arrayContainsAny: arrayContainsAny,
    whereIn: whereIn,
    whereNotIn: whereNotIn,
    isNull: isNull,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// T-37 · yalnızca eşitlik süzgeçli koleksiyon sorgusu: koşulduğunda
/// [_RecordingFirestore.queries]'e yazılır ve [_RecordingFirestore.docs]
/// içindeki eşleşen belgeleri (koleksiyonun doğrudan belgeleri) döndürür.
/// Başka işleç desteklenmez (sözleşmede yok).
final class _RecordingQuery implements Query<Json> {
  _RecordingQuery(this._collection, this._db, this._filters, this._limit);

  final String _collection;
  final _RecordingFirestore _db;
  final List<(String, Object?)> _filters;
  final int? _limit;

  @override
  Query<Json> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    final others = [
      isNotEqualTo,
      isLessThan,
      isLessThanOrEqualTo,
      isGreaterThan,
      isGreaterThanOrEqualTo,
      arrayContains,
      arrayContainsAny,
      whereIn,
      whereNotIn,
      isNull,
    ];
    if (field is! String || isEqualTo == null || others.any((v) => v != null)) {
      throw UnsupportedError('yalnızca eşitlik süzgeci: $field');
    }
    return _RecordingQuery(_collection, _db, [
      ..._filters,
      (field, isEqualTo),
    ], _limit);
  }

  @override
  Query<Json> limit(int limit) =>
      _RecordingQuery(_collection, _db, _filters, limit);

  @override
  Future<QuerySnapshot<Json>> get([GetOptions? options]) async {
    _db.queries.add({
      'collection': _collection,
      'where': [
        for (final (field, value) in _filters) [field, '==', value],
      ],
      'limit': ?_limit,
    });
    final direct = RegExp('^${RegExp.escape(_collection)}/[^/]+\$');
    final matches = [
      for (final MapEntry(key: path, value: data) in _db.docs.entries)
        if (direct.hasMatch(path) &&
            _filters.every((filter) => data[filter.$1] == filter.$2))
          _StoredQueryDoc(_RecordingReference(path, _db), data),
    ];
    return _StoredQuerySnapshot([
      ...matches.take(_limit ?? matches.length),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [_RecordingQuery] sonucunun belgeleri.
final class _StoredQuerySnapshot implements QuerySnapshot<Json> {
  _StoredQuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Json>> docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Sorgu sonucundaki tek belge (her zaman vardır).
final class _StoredQueryDoc implements QueryDocumentSnapshot<Json> {
  _StoredQueryDoc(this.reference, this._data);

  @override
  final DocumentReference<Json> reference;
  final Json _data;

  @override
  bool get exists => true;

  @override
  String get id => reference.id;

  @override
  Json data() => _data;

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
  Future<void> set(Json data, [SetOptions? options]) async {
    _db.log.add((
      op: 'set',
      path: path,
      data: data,
      merge: options?.merge ?? false,
    ));
    _db.commits.add(1);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    _db.log.add((op: 'update', path: path, data: data, merge: false));
    _db.commits.add(1);
  }

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
  _RecordingBatch(this._log, this._commits);

  final List<_Write> _log;
  final List<int> _commits;
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
  Future<void> commit() async {
    _log.addAll(_pending);
    if (_pending.isNotEmpty) _commits.add(_pending.length);
  }

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

/// T-42 · bu cihazın push jetonu (`updatedAt` istemci saati → `@daysAhead:0`).
final FcmTokenModel _fcmToken = FcmTokenModel(
  token: 'fcm-contract-token',
  platform: 'ios',
  locale: 'en',
  updatedAt: _scenarioNow,
);

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
        // T-42 (CD-165 d): girişte bu cihazın jetonu (transaction: hesap
        // okunur, tam liste + updatedAt yazılır) ve çıkışta aynı jetonun
        // çıkarılması. jest tarafı aynı yazımı sahibi olarak gönderir:
        // `fcmTokenOk` (locale dahil) + yalnızca yeni öğe denetimi.
        'UserRepository.upsertFcmToken · girişte bu cihazın jetonu (T-42)': () {
          db.docs['users/$uid/private/account'] = {
            FirestoreFields.fcmTokens: <Object?>[],
          };
          return users.upsertFcmToken(uid, _fcmToken);
        },
        'UserRepository.removeFcmToken · çıkışta bu cihazın jetonu (T-42)': () {
          db.docs['users/$uid/private/account'] = {
            FirestoreFields.fcmTokens: [_fcmToken.toJson()],
          };
          return users.removeFcmToken(uid, _fcmToken.token);
        },
        'SettingsRepository.updateSettings': () => settings.updateSettings(
          uid,
          const UserSettingsPatch(
            announcements: false,
            eventReminders: false,
            newEvents: false,
            newPosts: false,
            newComments: false,
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

  group('T-30 · Rules yük sözleşmesi (yönetim: üyelik kararları, ayar, '
      'yoklama)', () {
    final t30 = contract['t30']! as Map<String, Object?>;
    final fixtures = t30['fixtures']! as Map<String, Object?>;
    final actors = (t30['actors']! as Map<String, Object?>)
        .cast<String, String>();
    final scenarios = (t30['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final clock = FakeAppClock(_scenarioNow);
    const eventId = 'e01';

    late FirebaseMembershipRepository memberships;
    late FirebaseManagementRepository management;
    late FirebaseAttendanceRepository attendance;

    /// Sözleşmedeki her senaryonun gerçek repository karşılığı; argüman
    /// senaryonun `role` bağlamının uid'idir.
    late final calls =
        <String, Future<FirebaseResult<Object?, Object>> Function(String uid)>{
          'MembershipRepository.approve': (uid) => memberships.approve(
            clubId: clubId,
            userId: 'u_pending',
            actorId: uid,
          ),
          'MembershipRepository.reject': (uid) => memberships.reject(
            clubId: clubId,
            userId: 'u_pending',
            actorId: uid,
            reason: RejectReason.other,
            rejectNote: 'Kontenjan doldu.',
          ),
          'MembershipRepository.undoDecision · onayı geri al': (uid) =>
              memberships.undoDecision(
                clubId: clubId,
                userId: 'u_pending',
                actorId: uid,
              ),
          'MembershipRepository.undoDecision · reddi geri al': (uid) =>
              memberships.undoDecision(
                clubId: clubId,
                userId: 'u_pending',
                actorId: uid,
              ),
          'MembershipRepository.remove · yönetim kurulu → üye': (uid) =>
              memberships.remove(
                clubId: clubId,
                userId: 'u_member',
                actorId: uid,
                actorRole: ClubRole.board,
              ),
          'MembershipRepository.remove · süper admin → yönetim kurulu': (uid) =>
              memberships.remove(
                clubId: clubId,
                userId: 'u_board',
                actorId: uid,
                actorRole: ClubRole.member,
                actorIsSuper: true,
              ),
          'MembershipRepository.remove · silinmiş hesabın üyeliği (W-89 c)':
              (uid) => memberships.remove(
                clubId: clubId,
                userId: 'u_deleted',
                actorId: uid,
                actorRole: ClubRole.president,
              ),
          'MembershipRepository.undoRemoval': (uid) => memberships.undoRemoval(
            clubId: clubId,
            userId: 'u_member',
            actorId: uid,
          ),
          'MembershipRepository.changeRole · üye → yönetim kurulu': (uid) =>
              memberships.changeRole(
                clubId: clubId,
                userId: 'u_member',
                role: ClubRole.board,
                actorId: uid,
              ),
          'MembershipRepository.transferPresidency': (uid) =>
              memberships.transferPresidency(
                clubId: clubId,
                fromUserId: uid,
                toUserId: 'u_member',
                actorId: uid,
              ),
          'ManagementRepository.updateClubSettings': (uid) =>
              management.updateClubSettings(
                clubId,
                const ClubSettingsPatch(
                  summary: 'Yazılım ve donanım topluluğu.',
                  conditions: ['Aktif öğrenci olmak'],
                  applicationsOpen: false,
                  requireNote: true,
                ),
                actorId: uid,
              ),
          'ManagementRepository.updateClubSettings · SHT-31 şablona dön '
              '(kapak bırakılır)': (uid) => management.updateClubSettings(
            clubId,
            const ClubSettingsPatch(
              palette: ClubPalette.slate,
              pattern: ClubPattern.dots,
              coverSeed: 'sablon-1',
              clearCoverPath: true,
            ),
            actorId: uid,
          ),
          'AttendanceRepository.markAttended · going → attended': (uid) =>
              attendance.markAttended(
                eventId: eventId,
                userId: 'u_student',
                actorId: uid,
                attended: true,
              ),
          'AttendanceRepository.markAttended · attended → going (geri al)':
              (uid) => attendance.markAttended(
                eventId: eventId,
                userId: 'u_student',
                actorId: uid,
                attended: false,
              ),
          'AttendanceRepository.promote': (uid) => attendance.promote(
            eventId: eventId,
            userId: 'u_student',
            actorId: uid,
          ),
        };

    setUp(() {
      final service = FirebaseFirestoreService(db);
      final activity = FirebaseActivityRepository(service);
      // Gerçek dağıtıcı + yazıcı: kritik bildirimler aynı transaction'a
      // eklenir (W-83). Alıcı sorgusu bu senaryolarda çağrılmaz.
      final dispatcher = ClientFanOutDispatcher(
        writer: FirebaseNotificationRepository(service),
        recipients: const _FixedRecipients([]),
      );
      final events = FirebaseEventRepository(
        service,
        storage,
        activity,
        clock,
        SequenceRandom(_randomBytes),
      );
      final rsvps = FirebaseRsvpRepository(
        service,
        FakeTicketCodeGenerator(),
        clock,
      );
      memberships = FirebaseMembershipRepository(
        service,
        activity,
        dispatcher,
        clock,
      );
      management = FirebaseManagementRepository(
        firestore: service,
        storage: storage,
        clock: clock,
        random: SequenceRandom(_randomBytes),
        memberships: memberships,
        events: events,
        posts: FirebasePostRepository(
          service,
          storage,
          activity,
          FirebaseAnnouncementCounterRepository(service, clock),
          clock,
          SequenceRandom(_randomBytes),
        ),
        comments: FirebaseCommentRepository(service, clock),
        clubs: FirebaseClubRepository(service),
        activity: activity,
        notifications: dispatcher,
        recipients: const _FixedRecipients([]),
      );
      attendance = FirebaseAttendanceRepository(
        service,
        rsvps,
        dispatcher,
        clock,
      );
    });

    test('sözleşmedeki her senaryonun repository karşılığı var; fazlası '
        'yok', () {
      expect(
        scenarios.map((scenario) => scenario['call']),
        unorderedEquals(calls.keys),
      );
      expect(t30['autoId'], _autoId);
      expect(t30['increment'], _increment);
      expect(t30['daysAhead'], _daysAhead);
      expect(
        [
          for (final scenario in scenarios) ...[
            scenario['role'],
            for (final variant
                in (scenario['denied']! as List<Object?>)
                    .cast<Map<String, Object?>>())
              ?variant['role'],
          ],
        ],
        everyElement(isIn(actors.keys)),
      );
    });

    test('her yönetici yazma yolu en az bir senaryoda: PLAN §10.4 T-30 '
        "yüzeyi (yoklama okutması markAttended Tx'ini kullanır)", () {
      final covered = {
        for (final scenario in scenarios)
          (scenario['call']! as String).split(' · ').first,
      };

      expect(covered, {
        'MembershipRepository.approve',
        'MembershipRepository.reject',
        'MembershipRepository.undoDecision',
        'MembershipRepository.undoRemoval',
        'MembershipRepository.remove',
        'MembershipRepository.changeRole',
        'MembershipRepository.transferPresidency',
        'ManagementRepository.updateClubSettings',
        'AttendanceRepository.markAttended',
        'AttendanceRepository.promote',
      });
    });

    for (final scenario in scenarios) {
      final call = scenario['call']! as String;
      test('$call — okumalar, yazımlar ve işlem biçimi sözleşmeyle '
          'birebir', () async {
        final seed = scenario['seed']! as Map<String, Object?>;
        for (final MapEntry(key: path, value: entry) in seed.entries) {
          db.docs[path] = _seedDoc(fixtures, entry);
        }
        final uid = actors[scenario['role']]!;

        final result = await calls[call]!(uid);

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(db.reads, scenario['reads']);
        expect(_normalized(db.log), scenario['writes']);
        // Yönetici geçişleri tek transaction; ayar yazımı ön okuma + batch.
        expect(db.transactions, scenario['tx'] == true ? 1 : 0);
        expect(db.commits, [(scenario['writes']! as List<Object?>).length]);
      });
    }

    test('herkese açık kulüp / etkinlik belgesine sayaç işaretçisi yazılmaz; '
        'işaretçi yalnızca yan belgede ve kendi yazımını gösterir (W-64)', () {
      final writes = [
        for (final scenario in scenarios)
          for (final write in scenario['writes']! as List<Object?>)
            write! as Map<String, Object?>,
      ];
      final side = writes.where(
        (write) => (write['path']! as String).endsWith(
          '/${FirestoreCollections.privateSub}/'
          '${FirestoreCollections.counterDoc}',
        ),
      );

      for (final write in writes) {
        final path = write['path']! as String;
        final data = write['data']! as Map<String, Object?>;
        if (RegExp(r'^(clubs|events)/[^/]+$').hasMatch(path)) {
          expect(data.keys, isNot(contains(FirestoreFields.lastMembershipRef)));
          expect(data.keys, isNot(contains(FirestoreFields.lastRsvpRef)));
        }
      }
      expect(side, isNotEmpty);
      for (final write in side) {
        final data = write['data']! as Map<String, Object?>;
        expect(write['op'], 'set');
        expect(data[FirestoreFields.clubId], clubId);
        expect(data[FirestoreFields.updatedAt], _serverTimestamp);
        expect(data, hasLength(3));
      }
    });

    test('bozuk varyantlar yalnızca var olan yazım sıralarına dokunur; '
        '`swap` yalnızca dizgi → dizgi', () {
      for (final scenario in scenarios) {
        final writes = scenario['writes']! as List<Object?>;
        for (final variant
            in (scenario['denied']! as List<Object?>)
                .cast<Map<String, Object?>>()) {
          final reason = '${scenario['call']} · ${variant['name']}';
          final indexes = [
            ...(variant['without'] as List<Object?>? ?? const []).cast<int>(),
            ...(variant['patch'] as Map<String, Object?>? ?? const {}).keys.map(
              int.parse,
            ),
          ];
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
              'swap',
            }),
            isEmpty,
            reason: reason,
          );
          expect(variant.length, greaterThan(1), reason: reason);
          for (final MapEntry(:key, :value)
              in (variant['swap'] as Map<String, Object?>? ?? const {})
                  .entries) {
            expect(value, isA<String>(), reason: reason);
            expect(jsonEncode(writes), contains(key), reason: reason);
          }
        }
      }
    });
  });

  group('T-36 · Rules yük sözleşmesi (kulüp görselleri: logo / kapak)', () {
    final t36 = contract['t36']! as Map<String, Object?>;
    final fixtures = t36['fixtures']! as Map<String, Object?>;
    final actors = (t36['actors']! as Map<String, Object?>)
        .cast<String, String>();
    final scenarios = (t36['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final clock = FakeAppClock(_scenarioNow);

    /// Logo ve kapak aynı saniyede yüklenir: 16 bayt, iki ayrı ad.
    const randomBytes = [
      0x0a, 0x1b, 0x2c, 0x3d, 0x4e, 0x5f, 0x60, 0x71, //
      0x81, 0x92, 0xa3, 0xb4, 0xc5, 0xd6, 0xe7, 0xf8,
    ];

    late FirebaseManagementRepository management;

    ClubMediaUpload image(String contentType) =>
        ClubMediaUpload(bytes: _image, contentType: contentType);

    /// Sözleşmedeki her senaryonun gerçek repository karşılığı; argüman
    /// senaryonun `role` bağlamının uid'idir (= `uploaderId`).
    late final calls =
        <String, Future<FirebaseResult<Object?, Object>> Function(String uid)>{
          'ManagementRepository.updateClubMedia · logo + kapak': (uid) =>
              management.updateClubMedia(
                clubId,
                uploaderId: uid,
                logo: image('image/jpeg'),
                cover: image('image/png'),
              ),
          'ManagementRepository.updateClubMedia · yalnızca kapak': (uid) =>
              management.updateClubMedia(
                clubId,
                uploaderId: uid,
                cover: image('image/webp'),
              ),
        };

    setUp(() {
      final service = FirebaseFirestoreService(db);
      final activity = FirebaseActivityRepository(service);
      final dispatcher = ClientFanOutDispatcher(
        writer: FirebaseNotificationRepository(service),
        recipients: const _FixedRecipients([]),
      );
      management = FirebaseManagementRepository(
        firestore: service,
        storage: storage,
        clock: clock,
        random: SequenceRandom(randomBytes),
        memberships: FirebaseMembershipRepository(
          service,
          activity,
          dispatcher,
          clock,
        ),
        events: FirebaseEventRepository(
          service,
          storage,
          activity,
          clock,
          SequenceRandom(_randomBytes),
        ),
        posts: FirebasePostRepository(
          service,
          storage,
          activity,
          FirebaseAnnouncementCounterRepository(service, clock),
          clock,
          SequenceRandom(_randomBytes),
        ),
        comments: FirebaseCommentRepository(service, clock),
        clubs: FirebaseClubRepository(service),
        activity: activity,
        notifications: dispatcher,
        recipients: const _FixedRecipients([]),
      );
    });

    test('sözleşmedeki her senaryonun repository karşılığı var; fazlası '
        'yok; bağlamlar roles.json bağlamları', () {
      expect(
        scenarios.map((scenario) => scenario['call']),
        unorderedEquals(calls.keys),
      );
      expect(t36['autoId'], _autoId);
      expect(
        [
          for (final scenario in scenarios) ...[
            scenario['role'],
            for (final variant
                in (scenario['denied']! as List<Object?>)
                    .cast<Map<String, Object?>>())
              ?variant['role'],
          ],
        ],
        everyElement(isIn(actors.keys)),
      );
    });

    for (final scenario in scenarios) {
      final call = scenario['call']! as String;
      test('$call — okuma, yüklemeler, yazımlar ve işlem biçimi sözleşmeyle '
          'birebir', () async {
        final seed = scenario['seed']! as Map<String, Object?>;
        for (final MapEntry(key: path, value: entry) in seed.entries) {
          db.docs[path] = _seedDoc(fixtures, entry);
        }
        final uid = actors[scenario['role']]!;

        final result = await calls[call]!(uid);

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(db.reads, scenario['reads']);
        expect(
          [
            for (final upload in storage.uploads)
              {
                'path': upload.path,
                'contentType': upload.contentType,
                'customMetadata': upload.customMetadata,
              },
          ],
          scenario['uploads'],
        );
        expect(_normalized(db.log), scenario['writes']);
        // Ön okuma + tek batch (kulüp + günlük); transaction yok.
        expect(db.transactions, 0);
        expect(db.commits, [(scenario['writes']! as List<Object?>).length]);
      });
    }

    test("Firestore'a yazılan logoPath / coverPath yüklenen dosyaların "
        'yollarıdır ve kulübün klasöründedir (StoragePaths.isClubFile); '
        'üst veri yalnızca clubId + uploaderId (yükleyen = aktör)', () {
      for (final scenario in scenarios) {
        final uploads = (scenario['uploads']! as List<Object?>)
            .cast<Map<String, Object?>>();
        final writes = (scenario['writes']! as List<Object?>)
            .cast<Map<String, Object?>>();
        final club = writes.first['data']! as Map<String, Object?>;
        final activity = writes.last['data']! as Map<String, Object?>;
        final uid = actors[scenario['role']]!;

        expect(
          [club['logoPath'], club['coverPath']].nonNulls,
          uploads.map((upload) => upload['path']),
        );
        for (final upload in uploads) {
          expect(
            StoragePaths.isClubFile(upload['path']! as String, clubId),
            isTrue,
          );
          expect(upload['customMetadata'], {
            'clubId': clubId,
            'uploaderId': uid,
          });
        }
        expect(activity['actorId'], uid);
        expect(activity['kind'], ActivityKind.settingsChanged.json);
      }
    });

    test('bozuk varyantlar yalnızca var olan yazım sıralarına dokunur; '
        '`swap` yalnızca dizgi → dizgi', () {
      for (final scenario in scenarios) {
        final writes = scenario['writes']! as List<Object?>;
        for (final variant
            in (scenario['denied']! as List<Object?>)
                .cast<Map<String, Object?>>()) {
          final reason = '${scenario['call']} · ${variant['name']}';
          expect(
            (variant['patch'] as Map<String, Object?>? ?? const {}).keys.map(
              int.parse,
            ),
            everyElement(lessThan(writes.length)),
            reason: reason,
          );
          expect(
            variant.keys.toSet().difference({
              'name',
              'patch',
              'seed',
              'role',
              'swap',
            }),
            isEmpty,
            reason: reason,
          );
          expect(variant.length, greaterThan(1), reason: reason);
          for (final MapEntry(:key, :value)
              in (variant['swap'] as Map<String, Object?>? ?? const {})
                  .entries) {
            expect(value, isA<String>(), reason: reason);
            expect(jsonEncode(writes), contains(key), reason: reason);
          }
        }
      }
    });
  });

  group('T-37 · Rules yük sözleşmesi (süper admin: kulüp, kullanıcı, başkan, '
      'danışman, şikayet)', () {
    final t37 = contract['t37']! as Map<String, Object?>;
    final fixtures = t37['fixtures']! as Map<String, Object?>;
    final actors = (t37['actors']! as Map<String, Object?>)
        .cast<String, String>();
    final scenarios = (t37['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final clock = FakeAppClock(_scenarioNow);
    final superId = actors['super']!;
    const reason = 'Topluluk kurallarının ihlali.';

    late AdminRepository admin;

    /// Seed'deki kullanıcı belgesinin modeli (ADM-03 başkan seçimi profili
    /// `UserRepository.getUser` ile okur).
    UserModel seededUser(String uid) =>
        UserModel.fromJson(db.docs['users/$uid']!, id: uid);

    /// Sözleşmedeki her senaryonun gerçek repository karşılığı (aktör
    /// oturumdaki süper admindir).
    late final calls =
        <String, Future<FirebaseResult<Object?, Object>> Function()>{
          'AdminRepository.createClub': () => admin.createClub(
            const ClubCreateInput(
              name: 'Yeni Kulüp',
              nameLower: 'yeni kulüp',
              categoryId: 'k02',
              iconName: 'flask-conical',
              founded: 2024,
              palette: ClubPalette.slate,
              pattern: ClubPattern.dots,
              summary: 'Yeni kulübün özeti.',
            ),
            presidentUserId: 'u_student',
            presidentUser: seededUser('u_student'),
            presidentEmail: 'student@ogr.gumushane.edu.tr',
            advisor: const AdvisorInput(name: 'Ayşe Yılmaz', title: 'Doç. Dr.'),
          ),
          'AdminRepository.updateClubIdentity': () => admin.updateClubIdentity(
            clubId,
            const ClubIdentityPatch(
              name: 'Robotik Kulübü',
              nameLower: 'robotik kulübü',
              categoryId: 'k03',
              summary: 'Robotik topluluğu.',
              advisor: AdvisorInput(name: 'Ayşe Yılmaz', title: 'Doç. Dr.'),
            ),
          ),
          'AdminRepository.updateClubIdentity · SHT-31 şablona dön (kapak '
              'bırakılır)': () => admin.updateClubIdentity(
            clubId,
            const ClubIdentityPatch(
              categoryId: 'k03',
              palette: ClubPalette.slate,
              pattern: ClubPattern.dots,
              coverSeed: 'sablon-1',
              clearCoverPath: true,
            ),
          ),
          'AdminRepository.updateClubMedia · logo': () => admin.updateClubMedia(
            clubId,
            uploaderId: superId,
            logo: ClubMediaUpload(bytes: _image, contentType: 'image/jpeg'),
          ),
          'AdminRepository.suspendClub': () =>
              admin.suspendClub(clubId, reason: reason),
          'AdminRepository.activateClub': () => admin.activateClub(clubId),
          'AdminRepository.suspendUser': () =>
              admin.suspendUser('u_member', reason: reason),
          'AdminRepository.activateUser': () => admin.activateUser('u_susp'),
          'AdminRepository.assignPresident · üyeliği olmayan hedef (W-94)':
              () => admin.assignPresident(
                clubId: clubId,
                toUserId: 'u_student',
                actorId: superId,
              ),
          'AdminRepository.assignPresident · etkin üye (M11)': () =>
              admin.assignPresident(
                clubId: clubId,
                toUserId: 'u_member',
                actorId: superId,
              ),
          'AdminRepository.setAdvisor · bağla (M13)': () => admin.setAdvisor(
            clubId: clubId,
            userId: 'u_student',
            active: true,
          ),
          'AdminRepository.setAdvisor · kaldır (M13)': () => admin.setAdvisor(
            clubId: clubId,
            userId: 'u_advisor',
            active: false,
          ),
          'AdminRepository.resolveReports · removed (gönderi)': () =>
              admin.resolveReports(
                reportIds: const ['u_member_post_p01', 'u_student_post_p01'],
                action: ReportAction.removed,
                actorId: superId,
              ),
          'AdminRepository.resolveReports · dismissed (hedefli: kullanıcı)':
              () => admin.resolveReports(
                reportIds: const ['u_member_user_u_board'],
                action: ReportAction.dismissed,
                actorId: superId,
                target: (
                  type: ReportTargetType.user,
                  id: 'u_board',
                  clubId: null,
                ),
              ),
        };

    setUp(() {
      final service = FirebaseFirestoreService(db);
      final activity = FirebaseActivityRepository(service);
      final random = SequenceRandom(_randomBytes);
      final auth = ScriptedAuthService()
        ..currentUser = AuthUserInfo(
          uid: superId,
          email: 'super@gumushane.edu.tr',
          emailVerified: true,
        );
      // Gerçek dağıtıcı + yazıcı: `role_changed` / `report_resolved`
      // bildirimleri asıl yazımla aynı işlemdedir (W-83, W-84).
      final dispatcher = ClientFanOutDispatcher(
        writer: FirebaseNotificationRepository(service),
        recipients: const _FixedRecipients([]),
      );
      final posts = FirebasePostRepository(
        service,
        storage,
        activity,
        FirebaseAnnouncementCounterRepository(service, clock),
        clock,
        random,
      );
      admin = FirebaseAdminRepository(
        firestore: service,
        storage: storage,
        auth: auth,
        clock: clock,
        random: random,
        memberships: FirebaseMembershipRepository(
          service,
          activity,
          dispatcher,
          clock,
        ),
        reports: FirebaseReportModeration(
          firestore: service,
          auth: auth,
          posts: posts,
          comments: FirebaseCommentRepository(service, clock),
          dispatcher: dispatcher,
        ),
        search: FirebaseUserSearch(
          firestore: service,
          users: FirebaseUserRepository(service, storage, clock, random),
        ),
      );
    });

    test('sözleşmedeki her senaryonun repository karşılığı var; fazlası '
        'yok; tek bağlam süper admin; muafiyetler roles.json bağlamları', () {
      expect(
        scenarios.map((scenario) => scenario['call']),
        unorderedEquals(calls.keys),
      );
      expect(t37['autoId'], _autoId);
      expect(t37['increment'], _increment);
      expect(actors, {'super': 'u_super'});
      for (final scenario in scenarios) {
        expect(scenario['role'], 'super', reason: '${scenario['call']}');
        expect(
          scenario['exempt'] as List<Object?>? ?? const [],
          everyElement(isIn(_t37ClaimlessContexts)),
          reason: '${scenario['call']}',
        );
      }
    });

    test('AdminRepository yazma yüzeyinin her üyesi en az bir senaryoda '
        '(PLAN §10.4; okumalar ve stats yazmaz)', () {
      final covered = {
        for (final scenario in scenarios)
          (scenario['call']! as String).split(' · ').first,
      };

      expect(covered, {
        'AdminRepository.createClub',
        'AdminRepository.updateClubIdentity',
        'AdminRepository.updateClubMedia',
        'AdminRepository.suspendClub',
        'AdminRepository.activateClub',
        'AdminRepository.suspendUser',
        'AdminRepository.activateUser',
        'AdminRepository.assignPresident',
        'AdminRepository.setAdvisor',
        'AdminRepository.resolveReports',
      });
    });

    for (final scenario in scenarios) {
      final call = scenario['call']! as String;
      test('$call — sorgular, okumalar, yüklemeler, yazımlar ve işlem biçimi '
          'sözleşmeyle birebir', () async {
        final seed = scenario['seed']! as Map<String, Object?>;
        for (final MapEntry(key: path, value: entry) in seed.entries) {
          db.docs[path] = _seedDoc(fixtures, entry);
        }

        final result = await calls[call]!();

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(db.queries, scenario['queries'] ?? const <Object?>[]);
        expect(db.reads, scenario['reads']);
        expect(
          [
            for (final upload in storage.uploads)
              {
                'path': upload.path,
                'contentType': upload.contentType,
                'customMetadata': upload.customMetadata,
              },
          ],
          scenario['uploads'] ?? const <Object?>[],
        );
        expect(_normalized(db.log), scenario['writes']);
        expect(db.transactions, scenario['tx'] == true ? 1 : 0);
        // Her süper admin yazımı tek commit'tir (batch / transaction / tek
        // güncelleme): ya hepsi ya hiçbiri.
        expect(db.commits, [(scenario['writes']! as List<Object?>).length]);
      });
    }

    test('aktör kimliği yalnızca oturumdaki süper admin; yetki alanı '
        '(superadmin / role / isSuper) hiçbir yüke yazılmaz', () {
      final encoded = jsonEncode([
        for (final scenario in scenarios) scenario['writes'],
      ]);
      for (final key in ['superadmin', 'isSuper', 'isSuperAdmin']) {
        expect(encoded, isNot(contains('"$key"')));
      }
      for (final scenario in scenarios) {
        for (final write
            in (scenario['writes']! as List<Object?>)
                .cast<Map<String, Object?>>()) {
          final data = write['data']! as Map<String, Object?>;
          for (final field in [
            FirestoreFields.createdBy,
            FirestoreFields.resolvedBy,
            FirestoreFields.hiddenBy,
            FirestoreFields.actorId,
          ]) {
            if (data.containsKey(field)) {
              expect(data[field], superId, reason: '${write['path']}');
            }
          }
        }
      }
    });
  });

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
    // T-45: şikayet sayacının günü (`reportCounters/{uid}_{yyyyMMdd}`) —
    // senaryo saatinin Istanbul günü sözleşmede yer tutucudur (jest
    // emülatörün gününü koyar; T-19 ile aynı nöbetçiler).
    final clock = FakeAppClock(_scenarioNow);
    final dayKey = clock.istanbulDayKey(_scenarioNow);
    final day = clock.istanbulDay(_scenarioNow);
    String withDay(String text) =>
        text.replaceAll(_dayKeyToken, dayKey).replaceAll(_dayToken, day);
    String dayless(String text) =>
        text.replaceAll(dayKey, _dayKeyToken).replaceAll(day, _dayToken);
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
      reports = FirebaseReportRepository(service, clock);
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
      expect(t15['dayKey'], _dayKeyToken);
      expect(t15['day'], _dayToken);
      expect(student.profileComplete, isTrue);
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

        final result = await calls[call]!();

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(db.reads.map(dayless), scenario['reads']);
        expect(_mapStrings(_normalized(db.log), dayless), scenario['writes']);
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
  group('T-22 · Rules yük sözleşmesi (etkinlik / katılım)', () {
    final t22 = contract['t22']! as Map<String, Object?>;
    final fixtures = t22['fixtures']! as Map<String, Object?>;
    final actors = (t22['actors']! as Map<String, Object?>)
        .cast<String, String>();
    final scenarios = (t22['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final clock = FakeAppClock(_scenarioNow);
    const eventId = 'e01';
    DateTime daysAhead(int days) => _scenarioNow.add(Duration(days: days));

    // MGT-05 formunun iki biçimi: kontenjanlı, tablodan mekânlı herkese açık
    // etkinlik; kontenjansız, serbest metin mekânlı üyelere özel etkinlik
    // (boş alanların anahtarı yazılmaz — W-51).
    final workshop = EventDraft(
      title: 'Flutter atölyesi',
      desc: 'Mobil uygulama geliştirmeye giriş.',
      type: EventType.training,
      startsAt: daysAhead(7),
      endsAt: daysAhead(8),
      placeId: 'pl01',
      capacity: 30,
      coverPalette: ClubPalette.red,
      coverPattern: ClubPattern.dots,
    );
    final meeting = EventDraft(
      title: 'Kulüp içi toplantı',
      type: EventType.social,
      startsAt: daysAhead(5),
      endsAt: daysAhead(6),
      placeText: 'Kulüp odası',
      visibility: EventVisibility.membersOnly,
      coverPalette: ClubPalette.slate,
      coverPattern: ClubPattern.lines,
    );

    late EventRepository events;
    late RsvpRepository rsvps;

    Future<FirestoreResult<RsvpModel>> join(String uid) => rsvps.join(
      eventId: eventId,
      clubId: clubId,
      userId: uid,
      reminder: ReminderOption.oneHour,
    );
    Future<FirestoreResult<void>> leave(String uid) =>
        rsvps.cancel(eventId: eventId, userId: uid);

    /// Sözleşmedeki her senaryonun gerçek repository karşılığı; argüman
    /// senaryonun `role` bağlamının uid'idir.
    late final calls =
        <String, Future<FirebaseResult<Object?, Object>> Function(String uid)>{
          'EventRepository.createDraft': (uid) =>
              events.createDraft(workshop, clubId: clubId, createdBy: uid),
          'EventRepository.create · doğrudan yayın (üyelere özel, '
              'kontenjansız)': (uid) => events.create(
            meeting,
            clubId: clubId,
            createdBy: uid,
            status: EventStatus.published,
          ),
          'EventRepository.update · içerik (kontenjan, mekân, tarih)': (_) =>
              events.update(
                eventId,
                EventEditPatch(
                  title: 'Flutter atölyesi (2. oturum)',
                  capacity: 2,
                  placeId: 'pl02',
                  clearPlaceText: true,
                  startsAt: daysAhead(5),
                  endsAt: daysAhead(6),
                ),
              ),
          'EventRepository.publish · ilk yayın': (uid) =>
              events.publish(eventId, actorId: uid),
          'EventRepository.publish · yayından çekilmiş taslağı yeniden '
              'yayınla': (uid) =>
              events.publish(eventId, actorId: uid),
          'EventRepository.unpublish · bekleme listesi varken': (_) =>
              events.unpublish(eventId),
          'EventRepository.cancel': (uid) => events.cancel(
            eventId,
            reason: '  Salon tadilatta.  ',
            actorId: uid,
          ),
          'EventRepository.duplicate': (uid) => events.duplicate(
            eventId,
            createdBy: uid,
            copyTitleSuffix: ' (kopya)',
          ),
          'EventRepository.setRegistrationOpen · kaydı kapat': (_) =>
              events.setRegistrationOpen(eventId, false),
          'EventRepository.softDeleteEvent': (uid) =>
              events.softDeleteEvent(eventId, actorId: uid),
          'EventRepository.restoreEvent': (_) => events.restoreEvent(eventId),
          'EventRepository.uploadCover': (uid) => events.uploadCover(
            eventId,
            _image,
            contentType: 'image/jpeg',
            clubId: clubId,
            uploaderId: uid,
          ),
          'EventRepository.getEvent · taslak (danışman)': (_) =>
              events.getEvent(eventId),
          'EventRepository.getEvent · herkese açık (üye olmayan)': (_) =>
              events.getEvent(eventId),
          'RsvpRepository.join · yeni kayıt (going)': join,
          'RsvpRepository.join · kontenjan dolu → bekleme listesi': join,
          'RsvpRepository.join · yeniden katılım (cancelled → going)': join,
          'RsvpRepository.join · üyelere özel etkinlik (üye)': join,
          'RsvpRepository.join · istemcinin oluşturduğu etkinlik '
                  '(anahtarsız kontenjan — W-51)':
              join,
          'RsvpRepository.cancel · going': leave,
          'RsvpRepository.cancel · waitlist': leave,
          'RsvpRepository.cancel · askıdaki hesap': leave,
          'RsvpRepository.setReminder': (uid) => rsvps.setReminder(
            eventId: eventId,
            userId: uid,
            reminder: ReminderOption.oneDay,
          ),
          'RsvpRepository.getMine · kayıt yok': (uid) =>
              rsvps.getMine(eventId: eventId, userId: uid),
        };

    setUp(() {
      final service = FirebaseFirestoreService(db);
      events = FirebaseEventRepository(
        service,
        storage,
        FirebaseActivityRepository(service),
        clock,
        SequenceRandom(_randomBytes),
      );
      rsvps = FirebaseRsvpRepository(service, FakeTicketCodeGenerator(), clock);
    });

    test('sözleşmedeki her senaryonun repository karşılığı var; fazlası '
        'yok', () {
      expect(
        scenarios.map((scenario) => scenario['call']),
        unorderedEquals(calls.keys),
      );
      expect(t22['autoId'], _autoId);
      expect(t22['increment'], _increment);
      expect(t22['daysAhead'], _daysAhead);
      expect(
        scenarios.map((scenario) => scenario['role']),
        everyElement(isIn(actors.keys)),
      );
      // Bilet kodu sıralı üreticinin ilk kodudur (Rules deseni).
      expect(
        FakeTicketCodeGenerator.ticketCodeAt(1),
        matches(FirestoreIds.ticketCodePattern),
      );
    });

    test('her yazma metodu en az bir senaryoda: PLAN §10.4 T-22 yazma '
        'yüzeyi', () {
      final covered = {
        for (final scenario in scenarios)
          if ((scenario['writes']! as List<Object?>).isNotEmpty)
            (scenario['call']! as String).split(' · ').first,
      };

      expect(covered, {
        'EventRepository.createDraft',
        'EventRepository.create',
        'EventRepository.update',
        'EventRepository.publish',
        'EventRepository.unpublish',
        'EventRepository.cancel',
        'EventRepository.duplicate',
        'EventRepository.setRegistrationOpen',
        'EventRepository.softDeleteEvent',
        'EventRepository.restoreEvent',
        'EventRepository.uploadCover',
        'RsvpRepository.join',
        'RsvpRepository.cancel',
        'RsvpRepository.setReminder',
      });
    });

    for (final scenario in scenarios) {
      final call = scenario['call']! as String;
      test(
        '$call — okumalar, yazımlar ve yükleme sözleşmeyle birebir',
        () async {
          final seed = scenario['seed']! as Map<String, Object?>;
          for (final MapEntry(key: path, value: entry) in seed.entries) {
            db.docs[path] = _seedDoc(fixtures, entry);
          }
          final uid = actors[scenario['role']]!;

          final result = await calls[call]!(uid);

          expect(result.isSuccess, isTrue, reason: '$result');
          expect(db.reads, scenario['reads']);
          expect(_normalized(db.log), scenario['writes']);
          // Birden çok belgeyi okuyup yazan yollar tek transaction'dır.
          expect(db.transactions, scenario['tx'] == true ? 1 : 0);
          expect(
            [
              for (final upload in storage.uploads)
                {
                  'path': upload.path,
                  'contentType': upload.contentType,
                  'customMetadata': upload.customMetadata,
                },
            ],
            [?scenario['upload']],
          );
        },
      );
    }

    test("kapak: Firestore'a yazılan coverPath yüklenen dosyanın yoludur ve "
        'etkinliğin klasöründedir (CD-47)', () {
      final scenario = scenarios.singleWhere(
        (scenario) => scenario['call'] == 'EventRepository.uploadCover',
      );
      final upload = scenario['upload']! as Map<String, Object?>;
      final written =
          ((scenario['writes']! as List<Object?>).single!
                  as Map<String, Object?>)['data']!
              as Map<String, Object?>;

      expect(written['coverPath'], upload['path']);
      expect(
        StoragePaths.isEventCover(written['coverPath']! as String, eventId),
        isTrue,
      );
    });

    test('bozuk varyantlar yalnızca var olan yazım sıralarına dokunur', () {
      _expectWellFormedVariants(scenarios);
    });
  });

  group('T-25 · Rules yük sözleşmesi (bildirimler)', () {
    final t25 = contract['t25']! as Map<String, Object?>;
    final fixtures = t25['fixtures']! as Map<String, Object?>;
    final actors = (t25['actors']! as Map<String, Object?>)
        .cast<String, String>();
    final scenarios = (t25['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>();
    const eventId = 'e01';
    const seeded = 'announcement_AbCdEfGhIjKlMnOpQr01_u_student';
    const seeded2 = 'event_new_ZyXwVuTsRqPoNmLkJi23_u_student';

    late FirebaseFirestoreService service;
    late FirebaseNotificationRepository notifications;
    late ClientFanOutDispatcher dispatcher;

    /// Dağıtımın sözleşme sonucu: eksik yazım başarı sayılmaz.
    FirestoreResult<DispatchReport> complete(
      FirestoreResult<DispatchReport> result,
    ) => switch (result) {
      FirebaseSuccess(data: final report)
          when report.failedChunks > 0 || report.written < report.requested =>
        FirebaseFailure(FirestoreError.unknown, message: '$report'),
      _ => result,
    };

    /// Dağıtıcının batch üyesi (`notifyWaitlistPromoted`): terfi bileşimi
    /// (sözleşmenin ilk üç yazımı) + aynı batch'e eklenen bildirim. Gerçek
    /// `AttendanceRepository.promote` transaction'dır ve
    /// `notifyWaitlistPromotedInTransaction` kullanır — yükü `t30`
    /// senaryosundadır (W-83).
    Future<FirebaseResult<Object?, Object>> promote(String uid) async {
      late Future<FirestoreResult<DispatchReport>> dispatched;
      final committed = await service.commitBatch((batch) {
        batch
          ..update(service.doc(FirestoreCollections.rsvps, 'e01_u_student'), {
            FirestoreFields.status: RsvpStatus.going.json,
            ...BaseFieldsPayload.update(),
          })
          ..update(service.doc(FirestoreCollections.events, eventId), {
            FirestoreFields.goingCount: FieldValue.increment(1),
            FirestoreFields.waitlistCount: FieldValue.increment(-1),
            ...BaseFieldsPayload.update(),
          })
          ..set(service.doc('events/$eventId/private', 'counter'), {
            FirestoreFields.clubId: clubId,
            'lastRsvpRef': 'rsvps/e01_u_student',
            FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
          });
        dispatched = dispatcher.notifyWaitlistPromoted(
          eventId: eventId,
          clubId: clubId,
          userId: 'u_student',
          batch: batch,
        );
      });
      final report = complete(await dispatched);
      return committed.isSuccess ? report : committed;
    }

    /// Sözleşmedeki her senaryonun gerçek karşılığı; argüman senaryonun
    /// `role` bağlamının uid'idir.
    late final calls =
        <String, Future<FirebaseResult<Object?, Object>> Function(String uid)>{
          'NotificationDispatcher.notifyApplicationReceived': (uid) async =>
              complete(
                await dispatcher.notifyApplicationReceived(
                  clubId: clubId,
                  applicantId: uid,
                  sequence: 0,
                ),
              ),
          'NotificationDispatcher.notifyAnnouncement': (_) async => complete(
            await dispatcher.notifyAnnouncement(
              postId: 'p01',
              clubId: clubId,
              recipients: const ['u_member', 'u_board'],
            ),
          ),
          'NotificationDispatcher.notifyEventNew': (_) async => complete(
            await dispatcher.notifyEventNew(
              eventId: eventId,
              clubId: clubId,
              recipients: const ['u_member', 'u_president', 'u_student'],
            ),
          ),
          'NotificationDispatcher.notifyEventCancelled': (_) async => complete(
            await dispatcher.notifyEventCancelled(
              eventId: eventId,
              clubId: clubId,
              recipients: const ['u_student', 'u_member'],
            ),
          ),
          "NotificationDispatcher.notifyWaitlistPromoted · AttendanceRepository.promote (T-30) batch'i":
              promote,
          'NotificationRepository.createSelf · ilk dokunma': (uid) =>
              notifications.createSelf(
                userId: uid,
                eventId: eventId,
                clubId: clubId,
              ),
          'NotificationRepository.createSelf · belge zaten var (silinmiş)':
              (uid) => notifications.createSelf(
                userId: uid,
                eventId: eventId,
                clubId: clubId,
              ),
          'NotificationRepository.markRead': (_) =>
              notifications.markRead(seeded),
          'NotificationRepository.markAllRead': (uid) =>
              notifications.markAllRead(uid, const [seeded, seeded2, seeded]),
          'NotificationRepository.softDeleteNotification': (uid) =>
              notifications.softDeleteNotification(seeded, actorId: uid),
          'NotificationRepository.restoreNotification': (_) =>
              notifications.restoreNotification(seeded),
        };

    setUp(() {
      service = FirebaseFirestoreService(db);
      notifications = FirebaseNotificationRepository(service);
      dispatcher = ClientFanOutDispatcher(
        writer: notifications,
        recipients: const _FixedRecipients(['u_board', 'u_president']),
      );
    });

    test('sözleşmedeki her senaryonun karşılığı var; fazlası yok', () {
      expect(
        scenarios.map((scenario) => scenario['call']),
        unorderedEquals(calls.keys),
      );
      expect(t25['autoId'], _autoId);
      expect(t25['increment'], _increment);
      expect(
        scenarios.map((scenario) => scenario['role']),
        everyElement(isIn(actors.keys)),
      );
    });

    test('her yazma yolu en az bir senaryoda: NotificationRepository + '
        "Rules'ta açık dağıtıcı türleri", () {
      final created = {
        for (final scenario in scenarios)
          for (final write in scenario['writes']! as List<Object?>)
            if ((write! as Map<String, Object?>)['path']! as String
                case final path when path.startsWith('notifications/'))
              ((write as Map<String, Object?>)['data']!
                      as Map<String, Object?>)['type'] ??
                  '(güncelleme)',
      };
      final covered = {
        for (final scenario in scenarios)
          if ((scenario['writes']! as List<Object?>).isNotEmpty)
            (scenario['call']! as String).split(' · ').first,
      };

      expect(created, {
        'application_received',
        'announcement',
        'event_new',
        'event_cancelled',
        'waitlist_promoted',
        'event_reminder',
        '(güncelleme)',
      });
      expect(covered, {
        'NotificationDispatcher.notifyApplicationReceived',
        'NotificationDispatcher.notifyAnnouncement',
        'NotificationDispatcher.notifyEventNew',
        'NotificationDispatcher.notifyEventCancelled',
        'NotificationDispatcher.notifyWaitlistPromoted',
        'NotificationRepository.createSelf',
        'NotificationRepository.markRead',
        'NotificationRepository.markAllRead',
        'NotificationRepository.softDeleteNotification',
        'NotificationRepository.restoreNotification',
      });
    });

    for (final scenario in scenarios) {
      final call = scenario['call']! as String;
      test('$call — okumalar, yazımlar ve commit grupları sözleşmeyle '
          'birebir', () async {
        final seed = scenario['seed']! as Map<String, Object?>;
        for (final MapEntry(key: path, value: entry) in seed.entries) {
          db.docs[path] = _seedDoc(fixtures, entry);
        }
        final uid = actors[scenario['role']]!;
        final writes = scenario['writes']! as List<Object?>;
        final batches =
            (scenario['batches'] as List<Object?>?)
                ?.map((group) => (group! as List<Object?>).length)
                .toList() ??
            [if (writes.isNotEmpty) writes.length];

        final result = await calls[call]!(uid);

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(db.reads, scenario['reads']);
        expect(_normalized(db.log), writes);
        expect(db.commits, batches);
        expect(db.transactions, 0);
      });
    }

    test('bozuk varyantlar yalnızca var olan yazım sıralarına dokunur', () {
      _expectWellFormedVariants(scenarios);
    });
  });

  group('T-28 · Rules yük sözleşmesi (destek talebi)', () {
    final t28 = contract['t28']! as Map<String, Object?>;
    final actors = (t28['actors']! as Map<String, Object?>)
        .cast<String, String>();
    final scenarios = (t28['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>();

    late SupportRepository support;

    /// SET-05 formunun gerçek girdisi (konu "Hata bildirimi", ek SHT-16).
    late final calls =
        <String, Future<FirebaseResult<Object?, Object>> Function(String uid)>{
          'SupportRepository.createTicket · eksiz': (uid) =>
              support.createTicket(
                userId: uid,
                subject: SupportSubject.bug,
                message: 'Bildirimler gelmiyor.',
              ),
          'SupportRepository.createTicket · ekli (SHT-16)': (uid) =>
              support.createTicket(
                userId: uid,
                subject: SupportSubject.bug,
                message: 'Bildirimler gelmiyor.',
                attachment: SupportAttachment(
                  bytes: _image,
                  contentType: 'image/jpeg',
                ),
              ),
        };

    setUp(() {
      support = FirebaseSupportRepository(
        FirebaseFirestoreService(db),
        storage,
        FakeTicketCodeGenerator(),
        FakeAppClock(_uploadedAt),
        SequenceRandom(_randomBytes),
      );
    });

    test('sözleşmedeki her senaryonun repository karşılığı var; fazlası '
        'yok', () {
      expect(
        scenarios.map((scenario) => scenario['call']),
        unorderedEquals(calls.keys),
      );
      expect(
        scenarios.map((scenario) => scenario['role']),
        everyElement(isIn(actors.keys)),
      );
      // Talep numarası sıralı üreticinin ilk numarasıdır (Rules deseni).
      expect(
        FakeTicketCodeGenerator().supportTicketNo(),
        matches(FirestoreIds.supportTicketNoPattern),
      );
    });

    for (final scenario in scenarios) {
      final call = scenario['call']! as String;
      test('$call — yazım ve yükleme sözleşmeyle birebir; belge kimliği = '
          'ticketNo, ek talebin klasöründe', () async {
        final uid = actors[scenario['role']]!;

        final result = await calls[call]!(uid);

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(db.reads, scenario['reads']);
        expect(_normalized(db.log), scenario['writes']);
        expect(db.transactions, 0);
        expect(
          [
            for (final upload in storage.uploads)
              {
                'path': upload.path,
                'contentType': upload.contentType,
                'customMetadata': upload.customMetadata,
              },
          ],
          [?scenario['upload']],
        );
        final write =
            (scenario['writes']! as List<Object?>).single!
                as Map<String, Object?>;
        final data = write['data']! as Map<String, Object?>;
        expect(write['path'], 'supportTickets/${data['ticketNo']}');
        for (final path in (data['attachmentPaths']! as List<Object?>)) {
          expect(
            StoragePaths.isSupportFile(
              path! as String,
              data['ticketNo']! as String,
            ),
            isTrue,
          );
        }
      });
    }

    test('bozuk varyantlar yalnızca var olan yazım sıralarına dokunur', () {
      _expectWellFormedVariants(scenarios);
    });
  });

  group('T-29 · Rules yük sözleşmesi (hesap silme dizisi)', () {
    final t29 = contract['t29']! as Map<String, Object?>;
    final fixtures = t29['fixtures']! as Map<String, Object?>;
    final actors = (t29['actors']! as Map<String, Object?>)
        .cast<String, String>();
    final scenarios = (t29['scenarios']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final clock = FakeAppClock(_scenarioNow);

    late FirebaseMembershipRepository memberships;
    late FirebaseAccountDeletionRepository deletion;

    /// Parçaya verilen kayıt / üyelik: işlem güncel durumu kendisi okur;
    /// argümandan yalnızca kimlik alanları kullanılır.
    RsvpModel rsvp(String eventId, String uid) => RsvpModel(
      eventId: eventId,
      clubId: clubId,
      userId: uid,
      ticketCode: 'GU-AAAA-AAAB',
    );
    MembershipModel membership(String club, String uid) => MembershipModel(
      clubId: club,
      userId: uid,
      applicant: const MembershipApplicantModel(name: 'x', avatarSeed: 'x'),
    );

    /// Sözleşmedeki her senaryonun gerçek repository karşılığı; argüman
    /// senaryonun `role` bağlamının uid'idir.
    late final calls =
        <String, Future<FirebaseResult<Object?, Object>> Function(String uid)>{
          'AccountDeletionRepository.markDeleted': (uid) =>
              deletion.markDeleted(uid),
          'AccountDeletionRepository.markDeleted · zaten silinmiş (yeniden '
              'başlatma)': (uid) =>
              deletion.markDeleted(uid),
          'AccountDeletionRepository.cancelRsvpChunk · going + waitlist':
              (uid) => deletion.cancelRsvpChunk(uid, [
                rsvp('e01', uid),
                rsvp('e02', uid),
              ]),
          'AccountDeletionRepository.cancelRsvpChunk · yeniden başlatma (zaten '
              'vazgeçilmiş)': (uid) =>
              deletion.cancelRsvpChunk(uid, [rsvp('e01', uid)]),
          'MembershipRepository.anonymizeChunk · etkin üye + bekleyen + geçmiş '
              '(M14)': (uid) => memberships.anonymizeChunk(
            uid: uid,
            memberships: [
              membership('c01', uid),
              membership('c02', uid),
              membership('c03', uid),
            ],
          ),
          'MembershipRepository.anonymizeChunk · yeniden başlatma (anonim '
              'geçmiş üyelik)': (uid) => memberships.anonymizeChunk(
            uid: uid,
            memberships: [membership('c03', uid)],
          ),
          'MembershipRepository.anonymizeChunk · etkin başkan (durum aynı, '
              'applicant + contact)': (uid) => memberships.anonymizeChunk(
            uid: uid,
            memberships: [membership('c01', uid)],
          ),
          'AccountDeletionRepository.cancelUnreadableRsvp · ayrılınan '
              'kulübün üyelere özel etkinliği': (uid) =>
              deletion.cancelUnreadableRsvp(uid, rsvp('e01', uid)),
          'MembershipRepository.anonymizeChunk · danışman (sayaçsız left)':
              (uid) => memberships.anonymizeChunk(
                uid: uid,
                memberships: [membership('c01', uid)],
              ),
          'AccountDeletionRepository.softDeletePersonalChunk · bildirim + '
              'kayıt + engel': (uid) => deletion.softDeletePersonalChunk(uid, [
            const PersonalDocRef(PersonalDocKind.notification, 'n_del01'),
            PersonalDocRef(PersonalDocKind.savedPost, '${uid}_p01'),
            PersonalDocRef(PersonalDocKind.block, '${uid}_u_student'),
          ]),
        };

    setUp(() {
      final service = FirebaseFirestoreService(db);
      final activity = FirebaseActivityRepository(service);
      memberships = FirebaseMembershipRepository(
        service,
        activity,
        FakeNotificationDispatcher(),
        clock,
      );
      deletion = FirebaseAccountDeletionRepository(
        service,
        memberships,
        FirebaseRsvpRepository(service, FakeTicketCodeGenerator(), clock),
        FirebaseEventRepository(
          service,
          storage,
          activity,
          clock,
          SequenceRandom(_randomBytes),
        ),
        clock,
      );
    });

    test('sözleşmedeki her senaryonun repository karşılığı var; fazlası '
        'yok; dizi senaryolardan oluşur, sayaç nöbetçisi ortak', () {
      expect(
        scenarios.map((scenario) => scenario['call']),
        unorderedEquals(calls.keys),
      );
      expect(t29['increment'], _increment);
      expect(
        scenarios.map((scenario) => scenario['role']),
        everyElement(isIn(actors.keys)),
      );
      expect(t29['sequence'], everyElement(isIn(calls.keys)));
      expect(t29['restartAt'], lessThan((t29['sequence']! as List).length));
    });

    test('her yazma metodu en az bir senaryoda: AccountDeletionRepository '
        'parçaları + M14', () {
      final covered = {
        for (final scenario in scenarios)
          if ((scenario['writes']! as List<Object?>).isNotEmpty)
            (scenario['call']! as String).split(' · ').first,
      };
      expect(covered, {
        'AccountDeletionRepository.markDeleted',
        'AccountDeletionRepository.cancelRsvpChunk',
        'AccountDeletionRepository.cancelUnreadableRsvp',
        'MembershipRepository.anonymizeChunk',
        'AccountDeletionRepository.softDeletePersonalChunk',
      });
    });

    test('parça boyu Limits.accountDeletionChunk içinde; yükler '
        'Anonymization sabitleriyle aynı', () {
      final applicant =
          Anonymization.applicantPayload()[FirestoreFields.applicant];
      for (final scenario in scenarios) {
        for (final write in scenario['writes']! as List<Object?>) {
          final data =
              (write! as Map<String, Object?>)['data']! as Map<String, Object?>;
          if (data.containsKey('applicant')) {
            expect(data['applicant'], applicant);
          }
          if ((write as Map<String, Object?>)['path'] case final String path
              when path.startsWith('users/') && !path.contains('/private/')) {
            for (final MapEntry(:key, :value) in Anonymization.userPayload(
              'u_member',
            ).entries) {
              if (value is! FieldValue) expect(data[key], value, reason: key);
            }
          }
        }
      }
      final cancelled = scenarios.firstWhere(
        (scenario) => (scenario['call']! as String).startsWith(
          'AccountDeletionRepository.cancelRsvpChunk · going',
        ),
      );
      expect(
        (cancelled['writes']! as List).length ~/ 2,
        lessThanOrEqualTo(Limits.accountDeletionChunk),
      );
    });

    for (final scenario in scenarios) {
      final call = scenario['call']! as String;
      test('$call — okumalar ve yazımlar sözleşmeyle birebir', () async {
        final seed = scenario['seed']! as Map<String, Object?>;
        for (final MapEntry(key: path, value: entry) in seed.entries) {
          db.docs[path] = _seedDoc(fixtures, entry);
        }
        final uid = actors[scenario['role']]!;

        final result = await calls[call]!(uid);

        expect(result.isSuccess, isTrue, reason: '$result');
        expect(db.reads, scenario['reads']);
        expect(_normalized(db.log), scenario['writes']);
        // Birden çok belgeyi okuyup yazan parçalar tek transaction'dır.
        expect(db.transactions, scenario['tx'] == true ? 1 : 0);
      });
    }

    test('bozuk varyantlar yalnızca var olan yazım sıralarına dokunur', () {
      _expectWellFormedVariants(scenarios);
    });
  });
}

/// Sabit alıcılı [RecipientResolver] (sözleşme senaryoları): yönetici kümesi
/// verilir, diğer sorgular bu testte çağrılmaz.
/// T-37 · jest tarafının claim'siz ret bağlamları (roles.json `contexts` −
/// `super`); senaryonun `exempt` listesi yalnızca bunlardan olabilir.
const List<String> _t37ClaimlessContexts = [
  'anon',
  'unver',
  'student',
  'former',
  'pending',
  'member',
  'board',
  'president',
  'advisor',
  'otherManager',
  'susp',
];

final class _FixedRecipients implements RecipientResolver {
  const _FixedRecipients(this._managers);

  final List<String> _managers;

  @override
  Future<FirestoreResult<List<String>>> managersOf(String clubId) async =>
      FirebaseSuccess(_managers);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
