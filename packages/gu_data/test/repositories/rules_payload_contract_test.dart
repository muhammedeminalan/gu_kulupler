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
// SDK sınıfları `@sealed` işaretlidir; test çifti bilerek uygular.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

const String _contractPath = 'firebase/test/contracts/repository_payloads.json';

/// Sözleşme dosyasındaki sunucu zamanı nöbetçisi.
const String _serverTimestamp = '@serverTimestamp';

/// SDK'ya giden tek yazım.
typedef _Write = ({String op, String path, Object? data});

/// Yazımları [log]'a kaydeden veritabanı; okumalar "belge yok" döner.
final class _RecordingFirestore implements FirebaseFirestore {
  final List<_Write> log = [];

  @override
  CollectionReference<Json> collection(String collectionPath) =>
      _RecordingCollection(collectionPath, log);

  @override
  WriteBatch batch() => _RecordingBatch(log);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingCollection implements CollectionReference<Json> {
  _RecordingCollection(this.path, this._log);

  @override
  final String path;
  final List<_Write> _log;

  @override
  DocumentReference<Json> doc([String? path]) =>
      _RecordingReference('${this.path}/${path!}', _log);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingReference implements DocumentReference<Json> {
  _RecordingReference(this.path, this._log);

  @override
  final String path;
  final List<_Write> _log;

  @override
  String get id => path.split('/').last;

  @override
  Future<DocumentSnapshot<Json>> get([GetOptions? options]) async =>
      _MissingSnapshot(this);

  @override
  Future<void> set(Json data, [SetOptions? options]) async =>
      _log.add((op: 'set', path: path, data: data));

  @override
  Future<void> update(Map<Object, Object?> data) async =>
      _log.add((op: 'update', path: path, data: data));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MissingSnapshot implements DocumentSnapshot<Json> {
  _MissingSnapshot(this.reference);

  @override
  final DocumentReference<Json> reference;

  @override
  bool get exists => false;

  @override
  String get id => reference.id;

  @override
  Json? data() => null;

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
/// [_serverTimestamp] olur; başka her `FieldValue` hatadır (sözleşmede yok).
Object? _normalize(Object? value) => switch (value) {
  final FieldValue field when field == FieldValue.serverTimestamp() =>
    _serverTimestamp,
  FieldValue() => throw StateError('beklenmeyen FieldValue: $value'),
  final Map<Object?, Object?> map => {
    for (final entry in map.entries) entry.key: _normalize(entry.value),
  },
  final List<Object?> list => [for (final item in list) _normalize(item)],
  _ => value,
};

List<Object?> _normalized(List<_Write> writes) => [
  for (final write in writes)
    {'op': write.op, 'path': write.path, 'data': _normalize(write.data)},
];

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
        'UserRepository.updateProfile · AUT-05 bitişi': () =>
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
        // Kayıt tutan çiftte belge yoktur: `getSettings` varsayılanı yazar.
        'SettingsRepository.getSettings · belge yok': () =>
            settings.getSettings(uid),
      };

  setUp(() {
    db = _RecordingFirestore();
    final service = FirebaseFirestoreService(db);
    users = FirebaseUserRepository(service);
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
  });
}
