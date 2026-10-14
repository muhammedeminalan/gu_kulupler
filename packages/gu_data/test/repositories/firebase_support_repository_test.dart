// T-28 · SupportRepository: destek talebi `supportTickets/{ticketNo}` —
// numara `GU-XXXXXX` (kriptografik kaynak, karışan harfler yok — D-30),
// belge kimliği = numara; numara çakışmasında (Rules: var olan belgeye
// yazım = update → `permission-denied`) bir kez yeni numarayla yeniden
// deneme; ek önce `support/{ticketNo}/{yeni ad}` yoluna
// `customMetadata.uploaderId` ile, sonra belge (en çok 1, ≤ 5 MB,
// jpeg / png / webp); ön denetim dosya göndermeden; hata eşlemesi; kendi
// taleplerini listeleme (PLAN §10.4; rules-spec §3.15, §7).
//
// Mutlu yollar `fake_cloud_firestore` ile; Rules'ın çakışma reddi ve hata
// enjeksiyonu el yazımı servis çiftiyle (`_RulesLikeFirestoreService`).
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/fake_ticket_code_generator.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/recording_storage_service.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/support_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_support_repository.dart';

const String _me = 'u_mehmet';
const String _other = 'u_ayse';
const String _message = 'Bildirimler gelmiyor.';

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'u/1', '..', '__id__'];

final DateTime _now = DateTime.utc(2026, 10, 14, 9);

/// `FakeTicketCodeGenerator` sırası: 1. ve 2. numara.
final String _first = FakeTicketCodeGenerator.supportTicketNoAt(1);
final String _second = FakeTicketCodeGenerator.supportTicketNoAt(2);

/// Rules'ın bu yola bakan iki davranışını taklit eden servis: var olan
/// belgeye `set` (= update) `permission-denied` alır; [nextSetError] bir
/// sonraki yazımı o hatayla düşürür. Her yazım [sets] listesine düşer.
final class _RulesLikeFirestoreService implements FirestoreService {
  _RulesLikeFirestoreService(this._db) : _inner = FirebaseFirestoreService(_db);

  final FakeFirebaseFirestore _db;
  final FirestoreService _inner;

  /// Yazım denemeleri (reddedilenler dahil), sırayla.
  final List<({String path, Json data})> sets = [];

  /// Verilirse bir sonraki [set] bu hatayla biter (tek seferlik).
  FirestoreError? nextSetError;

  @override
  Future<FirestoreResult<void>> set(
    DocumentReference<Json> ref,
    Json data, {
    bool merge = false,
  }) async {
    sets.add((path: ref.path, data: normalizePayload(data)! as Json));
    final error = nextSetError;
    nextSetError = null;
    if (error != null) return FirebaseFailure(error);
    if ((await _db.doc(ref.path).get()).exists) {
      return const FirebaseFailure(FirestoreError.permissionDenied);
    }
    return _inner.set(ref, data, merge: merge);
  }

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  String newId(String collectionPath) => _inner.newId(collectionPath);

  @override
  Query<Json> collection(String path) => _inner.collection(path);

  @override
  Query<Json> collectionGroup(String collectionId) =>
      _inner.collectionGroup(collectionId);

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(DocumentReference<Json> ref) =>
      _inner.getDoc(ref);

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query) =>
      _inner.getList(query);

  @override
  Future<FirestoreResult<PageResult<FirestoreDoc>>> getPage(
    Query<Json> query,
    PageRequest page,
  ) => _inner.getPage(query, page);

  @override
  Stream<FirestoreResult<FirestoreDoc?>> watchDoc(
    DocumentReference<Json> ref,
  ) => _inner.watchDoc(ref);

  @override
  Stream<FirestoreResult<List<FirestoreDoc>>> watchList(Query<Json> query) =>
      _inner.watchList(query);

  @override
  Future<FirestoreResult<String>> add(String collectionPath, Json data) =>
      _inner.add(collectionPath, data);

  @override
  Future<FirestoreResult<void>> update(
    DocumentReference<Json> ref,
    Json fields, {
    bool touchUpdatedAt = true,
  }) => _inner.update(ref, fields, touchUpdatedAt: touchUpdatedAt);

  @override
  Future<FirestoreResult<T>> runTransaction<T>(
    Future<T> Function(Transaction tx) body,
  ) => _inner.runTransaction(body);

  @override
  Future<FirestoreResult<void>> commitBatch(
    void Function(WriteBatch batch) build,
  ) => _inner.commitBatch(build);

  @override
  Future<FirestoreResult<void>> softDelete(
    DocumentReference<Json> ref, {
    required String actorId,
    WriteBatch? batch,
  }) => _inner.softDelete(ref, actorId: actorId, batch: batch);

  @override
  Future<FirestoreResult<void>> restore(
    DocumentReference<Json> ref, {
    WriteBatch? batch,
  }) => _inner.restore(ref, batch: batch);

  @override
  Future<FirestoreResult<int>> count(Query<Json> query) => _inner.count(query);

  @override
  Object serverTimestamp() => _inner.serverTimestamp();
}

SupportAttachment _image({String contentType = 'image/png', int length = 3}) =>
    SupportAttachment(bytes: Uint8List(length), contentType: contentType);

/// Yazılan talep belgesinin beklenen yükü.
Json _payload(String ticketNo, {List<String> paths = const []}) => {
  'ticketNo': ticketNo,
  'userId': _me,
  'subject': 'bug',
  'message': _message,
  'attachmentPaths': paths,
  'status': 'open',
  'isDeleted': false,
  'createdAt': serverTimestampMark,
  'updatedAt': serverTimestampMark,
  'deletedAt': null,
  'deletedBy': null,
};

void main() {
  late FakeFirebaseFirestore db;
  late _RulesLikeFirestoreService firestore;
  late RecordingStorageService storage;
  late FakeTicketCodeGenerator codes;
  late SupportRepository repository;

  /// Sırayla artan baytlar: dosya adının rastgele kısmı sabittir.
  final random = List<int>.generate(64, (i) => i);
  String fileName(int from) =>
      '20261014T090000Z_${[for (var i = from; i < from + 8; i++) i.toRadixString(16).padLeft(2, '0')].join()}.png';

  Future<MediaUpdateResult<SupportTicketModel>> create({
    String userId = _me,
    String message = _message,
    SupportAttachment? attachment,
  }) => repository.createTicket(
    userId: userId,
    subject: SupportSubject.bug,
    message: message,
    attachment: attachment,
  );

  Future<void> seedTicket(String ticketNo, {String userId = _other}) =>
      db.doc('supportTickets/$ticketNo').set({
        'ticketNo': ticketNo,
        'userId': userId,
        'subject': 'other',
        'message': 'Önceki talep',
        'attachmentPaths': <String>[],
        'status': 'open',
        'isDeleted': false,
      });

  setUp(() {
    db = FakeFirebaseFirestore();
    firestore = _RulesLikeFirestoreService(db);
    storage = RecordingStorageService();
    codes = FakeTicketCodeGenerator();
    repository = FirebaseSupportRepository(
      firestore,
      storage,
      codes,
      FakeAppClock(_now),
      SequenceRandom(random),
    );
  });

  group('T-28 · SupportRepository · sözleşme', () {
    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });

    test('numara biçimi: SecureTicketCodeGenerator `GU-XXXXXX` üretir, '
        'karışan harfler (I, O, 0, 1) yok; belge kimliği = numara', () async {
      final secure = FirebaseSupportRepository(
        firestore,
        storage,
        SecureTicketCodeGenerator.withRandom(Random(28)),
        FakeAppClock(_now),
        SequenceRandom(random),
      );
      final pattern = RegExp(FirestoreIds.supportTicketNoPattern);
      for (var i = 0; i < 20; i++) {
        final ticket = (await secure.createTicket(
          userId: _me,
          subject: SupportSubject.other,
          message: _message,
        )).dataOrNull!;
        expect(
          pattern.hasMatch(ticket.ticketNo),
          isTrue,
          reason: ticket.ticketNo,
        );
        expect(ticket.ticketNo.substring(3), isNot(contains(RegExp('[IO01]'))));
        expect(ticket.id, ticket.ticketNo);
        expect(FieldValidators.supportTicketNo(ticket.ticketNo), isNull);
      }
      expect(firestore.sets.map((s) => s.path).toSet(), hasLength(20));
    });
  });

  group('T-28 · createTicket · yazım', () {
    test('eksiz talep: supportTickets/{ticketNo} belgesi tam yükle '
        '(status open, sunucu zamanı); Storage yüklemesi yok', () async {
      final result = await create();

      final ticket = result.dataOrNull!;
      expect(ticket.ticketNo, _first);
      expect(ticket.id, _first);
      expect(ticket.userId, _me);
      expect(ticket.subject, SupportSubject.bug);
      expect(ticket.status, TicketStatus.open);
      expect(ticket.attachmentPaths, isEmpty);
      expect(ticket.createdAt, _now);
      expect(firestore.sets.map((s) => s.path), ['supportTickets/$_first']);
      expect(firestore.sets.single.data, _payload(_first));
      expect(storage.uploads, isEmpty);
      expect((await db.doc('supportTickets/$_first').get()).exists, isTrue);
    });

    test('ekli talep: önce support/{ticketNo}/{yeni ad} yoluna yalnızca '
        'uploaderId üst verisiyle yükleme, sonra yolu taşıyan belge', () async {
      final attachment = _image();
      final result = await create(attachment: attachment);

      final path = 'support/$_first/${fileName(0)}';
      expect(storage.uploads, hasLength(1));
      final upload = storage.uploads.single;
      expect(upload.path, path);
      expect(StoragePaths.isSupportFile(upload.path, _first), isTrue);
      expect(upload.bytes, same(attachment.bytes));
      expect(upload.contentType, 'image/png');
      expect(upload.customMetadata, {'uploaderId': _me});
      expect(result.dataOrNull!.attachmentPaths, [path]);
      expect(firestore.sets.single.data, _payload(_first, paths: [path]));
    });

    test('jpeg / png / webp kabul; uzantı içerik türünden', () async {
      for (final (type, ext) in [
        ('image/jpeg', 'jpg'),
        ('image/png', 'png'),
        ('image/webp', 'webp'),
      ]) {
        final result = await create(attachment: _image(contentType: type));
        expect(result.dataOrNull!.attachmentPaths.single, endsWith('.$ext'));
      }
    });
  });

  group('T-28 · createTicket · numara çakışması', () {
    test(
      'var olan numara (Rules reddi) → bir kez yeni numarayla yeniden '
      'yazılır; ek yeni klasöre yeniden yüklenir, eski belge değişmez',
      () async {
        await seedTicket(_first);

        final result = await create(attachment: _image());

        expect(result.dataOrNull!.ticketNo, _second);
        expect(codes.issuedSupportTicketNos, [_first, _second]);
        expect(firestore.sets.map((s) => s.path), [
          'supportTickets/$_first',
          'supportTickets/$_second',
        ]);
        expect(storage.uploads.map((u) => u.path), [
          'support/$_first/${fileName(0)}',
          'support/$_second/${fileName(8)}',
        ]);
        expect(result.dataOrNull!.attachmentPaths, [
          'support/$_second/${fileName(8)}',
        ]);
        expect((await db.doc('supportTickets/$_first').get()).data(), {
          'ticketNo': _first,
          'userId': _other,
          'subject': 'other',
          'message': 'Önceki talep',
          'attachmentPaths': <String>[],
          'status': 'open',
          'isDeleted': false,
        });
      },
    );

    test('ikinci deneme de reddedilirse sonuç nihaidir: '
        'MediaDocumentError(permissionDenied), üçüncü deneme yok', () async {
      await seedTicket(_first);
      await seedTicket(_second);

      final result = await create();

      expect(
        result.errorOrNull,
        const MediaDocumentError(FirestoreError.permissionDenied),
      );
      expect(firestore.sets, hasLength(2));
      expect(codes.issuedSupportTicketNos, [_first, _second]);
    });

    test('ağ hatası çakışma sayılmaz: yeniden deneme yok, yüklenen ek '
        'yerinde kalır (D-10)', () async {
      firestore.nextSetError = FirestoreError.unavailable;

      final result = await create(attachment: _image());

      expect(
        result.errorOrNull,
        const MediaDocumentError(FirestoreError.unavailable),
      );
      expect(firestore.sets, hasLength(1));
      expect(storage.uploads, hasLength(1));
    });
  });

  group('T-28 · createTicket · ön denetim ve hata eşlemesi', () {
    test(
      'geçersiz kimlik, boş ya da 500 karakterden uzun mesaj → '
      'MediaDocumentError(invalidArgument); hiçbir şey gönderilmez',
      () async {
        final results = [
          for (final id in _invalidIds) await create(userId: id),
          await create(message: ''),
          await create(message: 'a' * (Limits.supportMessageMax + 1)),
        ];

        for (final result in results) {
          expect(
            result.errorOrNull,
            const MediaDocumentError(FirestoreError.invalidArgument),
          );
        }
        expect(firestore.sets, isEmpty);
        expect(storage.uploads, isEmpty);
        expect(codes.issuedSupportTicketNos, isEmpty);
      },
    );

    test('tam 500 karakterlik mesaj kabul edilir', () async {
      final result = await create(message: 'a' * Limits.supportMessageMax);
      expect(result.dataOrNull!.message.length, Limits.supportMessageMax);
    });

    test('ek sınırları: izinsiz tür → invalidType, boş → noFile, 5 MB ve '
        'üstü → sizeLimit; dosya ve belge gönderilmez', () async {
      final cases = {
        _image(contentType: 'image/gif'): StorageError.invalidType,
        _image(contentType: 'image/svg+xml'): StorageError.invalidType,
        _image(length: 0): StorageError.noFile,
        _image(length: Limits.imageMaxBytes): StorageError.sizeLimit,
      };
      for (final MapEntry(key: attachment, value: error) in cases.entries) {
        final result = await create(attachment: attachment);
        expect(result.errorOrNull, MediaUploadError(error));
      }
      expect(storage.uploads, isEmpty);
      expect(firestore.sets, isEmpty);

      final under = await create(
        attachment: _image(length: Limits.imageMaxBytes - 1),
      );
      expect(under.isSuccess, isTrue);
    });

    test('yükleme reddi / ağ → MediaUploadError; belge yazılmaz, yeniden '
        'deneme yok', () async {
      storage.nextError = StorageError.unauthorized;

      final result = await create(attachment: _image());

      expect(
        result.errorOrNull,
        const MediaUploadError(StorageError.unauthorized),
      );
      expect(firestore.sets, isEmpty);
      expect(storage.uploads, hasLength(1));
    });
  });

  group('T-28 · listMine', () {
    test(
      'yalnızca kendi talepleri, en yeni önce; silinmiş kayıt yok',
      () async {
        Future<void> put(
          String no,
          String userId,
          int hour, {
          bool deleted = false,
        }) => db.doc('supportTickets/$no').set({
          'ticketNo': no,
          'userId': userId,
          'subject': 'bug',
          'message': _message,
          'attachmentPaths': <String>[],
          'status': 'open',
          'isDeleted': deleted,
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, hour)),
        });
        await put('GU-AAAAAD', _me, 8);
        await put('GU-AAAAAE', _me, 10);
        await put('GU-AAAAAF', _other, 11);
        await put('GU-AAAAAG', _me, 12, deleted: true);

        final result = await repository.listMine(_me);

        expect(result.dataOrNull!.map((t) => t.ticketNo), [
          'GU-AAAAAE',
          'GU-AAAAAD',
        ]);
        expect(result.dataOrNull!.first.id, 'GU-AAAAAE');
      },
    );

    test(
      'geçersiz kimlik → invalidArgument; ayrıştırılamayan kayıt → parse',
      () async {
        for (final id in _invalidIds) {
          expect(
            (await repository.listMine(id)).errorOrNull,
            FirestoreError.invalidArgument,
          );
        }
        await db.doc('supportTickets/GU-AAAAAH').set({
          'ticketNo': 'GU-AAAAAH',
          'userId': _me,
          'subject': 'bilinmeyen',
          'message': _message,
        });
        expect(
          (await repository.listMine(_me)).errorOrNull,
          FirestoreError.parse,
        );
      },
    );
  });
}
