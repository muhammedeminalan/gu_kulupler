import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/enums/notification_type.dart';
import 'package:gu_data/src/models/notification_draft.dart';
import 'package:gu_data/src/models/notification_model.dart';
import 'package:gu_data/src/models/notification_refs_model.dart';
import 'package:gu_data/src/notifications/notification_writer.dart';
import 'package:gu_data/src/repositories/notification_repository.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// [NotificationRepository] ve [NotificationWriter] uygulaması:
/// `notifications/{type}_{eventKey}_{userId}` (PLAN §10.4; rules-spec §3.9;
/// `docs/plans/T-25.md` §6).
///
/// **Okuma / güncelleme** sahibinin kendi belgeleri üzerindedir: canlı gelen
/// kutusu (`userId == uid ∧ isDeleted == false`, en yeni üstte), okundu
/// işareti (`read: true` + `updatedAt`), "Tümünü okundu say"
/// ([Limits.batchMaxWrites] boyutlu parçalı batch), kaydırarak silme (soft
/// delete) ve "Geri al" (restore). Belge silme yoktur (D-10). Başkasının
/// bildirimine dokunan her çağrı Security Rules'ta reddedilir ve
/// [FirestoreError.permissionDenied] döner; repository aktöre göre dallanmaz.
///
/// **Yazım** kördür (önce okuma yok — [createSelf] hariç): her belge
/// `userId`, `type`, `refs` (yalnızca dolu referanslar — W-51), `read:
/// false` ve `BaseFieldsPayload.create` alanlarını taşır; metin ve aktör
/// alanı yazılmaz. Taslak ([NotificationDraft]) ve alıcı kimlikleri yazımdan
/// önce doğrulanır: tanınmayan tür, geçersiz olay anahtarı, eksik zorunlu
/// referans (`NotificationRefsModel.requiredFor`) ya da geçersiz alıcı
/// kimliği hiçbir şey yazmadan [FirestoreError.invalidArgument] olur.
final class FirebaseNotificationRepository
    implements NotificationRepository, NotificationWriter {
  /// [_firestore] servisi üzerinden okur ve yazar.
  FirebaseNotificationRepository(this._firestore);

  final FirestoreService _firestore;

  /// `addToBatch` doğrulama hatasının SDK kodu: `commitBatch` gövdesinden
  /// fırlatıldığında [FirestoreError.invalidArgument] olarak eşlenir.
  static const String _invalidArgumentCode = 'invalid-argument';

  /// `addToBatch` doğrulama hatasının eklenti adı (SDK hatalarıyla aynı).
  static const String _plugin = 'cloud_firestore';

  // ── NotificationRepository ──────────────────────────────────────────────

  @override
  Stream<FirestoreResult<List<NotificationModel>>> watchInbox(
    String userId, {
    int limit = Limits.notificationInboxLimit,
  }) {
    if (RepositoryHelpers.rejectInvalidIds<List<NotificationModel>>({
          'userId': userId,
        })
        case final rejected?) {
      return Stream.value(rejected);
    }
    if (limit < 1) {
      return Stream.value(
        RepositoryHelpers.invalidArgument('geçersiz limit: $limit'),
      );
    }
    // Sorgu sözleşmesi (rules-spec §6 NTF-01; indeks userId ↑, isDeleted ↑,
    // createdAt ↓): sahibi + silinmemiş, en yeni üstte. Tercih süzgeci ve
    // okunmamış sayısı okuyan tarafta (ViewModel) bu akıştan çıkar.
    return _firestore
        .watchList(
          _notifications
              .where(FirestoreFields.userId, isEqualTo: userId)
              .notDeleted()
              .orderBy(FirestoreFields.createdAt, descending: true)
              .limit(limit),
        )
        .map((event) => RepositoryHelpers.parseAll(event, _notificationOf));
  }

  @override
  Future<FirestoreResult<void>> markRead(String notificationId) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'notificationId': notificationId,
        })
        case final rejected?) {
      return rejected;
    }
    // `updatedAt` servis tarafından eklenir (Rules `touches(['read'])`).
    return _firestore.update(_byId(notificationId), {
      FirestoreFields.read: true,
    });
  }

  @override
  Future<FirestoreResult<void>> markAllRead(
    String userId,
    List<String> unreadIds,
  ) async {
    final ids = unreadIds.toSet().toList();
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({'userId': userId}) ??
        RepositoryHelpers.rejectInvalidIds<void>({
          for (final (index, id) in ids.indexed) 'unreadIds[$index]': id,
        });
    if (rejected != null) return rejected;

    // Parçalar sırayla işlenir; ilk başarısız parçada durulur. Önceki
    // parçalar yazılmış kalır: okundu işareti geri alınmaz, yeniden çağrı
    // aynı belgelere yeniden `read: true` yazar (Rules buna izin verir).
    for (final chunk in ids.slices(Limits.batchMaxWrites)) {
      final written = await _firestore.commitBatch((batch) {
        for (final id in chunk) {
          batch.update(_byId(id), {
            FirestoreFields.read: true,
            ...BaseFieldsPayload.update(),
          });
        }
      });
      if (written case FirebaseFailure()) return written;
    }
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> softDeleteNotification(
    String notificationId, {
    required String actorId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'notificationId': notificationId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    return _firestore.softDelete(_byId(notificationId), actorId: actorId);
  }

  @override
  Future<FirestoreResult<void>> restoreNotification(
    String notificationId,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'notificationId': notificationId,
        })
        case final rejected?) {
      return rejected;
    }
    // "Yalnızca silen sahibi" koşulu Rules'tadır (`deletedBy == uid()`).
    return _firestore.restore(_byId(notificationId));
  }

  @override
  Future<FirestoreResult<void>> createSelf({
    required String userId,
    required String eventId,
    required String clubId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'userId': userId,
          'eventId': eventId,
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    // Hatırlatıcı belgesinin kimliği deterministiktir (anahtar = etkinlik):
    // ikinci dokunma yeni belge üretmez. Var olan belgeye `set` Rules'ta
    // güncelleme sayılacağından önce okunur; silinmiş belge de "var"dır
    // (kullanıcının sildiği hatırlatıcı yeniden canlanmaz).
    final draft = NotificationDraft(
      type: NotificationType.eventReminder,
      eventKey: eventId,
      refs: NotificationRefsModel(clubId: clubId, eventId: eventId),
    );
    final ref = _ref(draft, userId);
    switch (await _firestore.getDoc(ref)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: _?):
        return const FirebaseSuccess(null);
      case FirebaseSuccess(data: null):
        return _firestore.set(ref, _payload(draft, userId));
    }
  }

  // ── NotificationWriter ──────────────────────────────────────────────────

  @override
  String newEventKey() => _firestore.newId(FirestoreCollections.notifications);

  /// [draft] ya da [recipientId] geçersizse (sınıf belgesi) batch'e hiçbir
  /// şey eklenmez ve `invalid-argument` kodlu [FirebaseException] fırlatılır:
  /// `FirestoreService.commitBatch` gövdesinde bu
  /// [FirestoreError.invalidArgument] olur ve batch'in **hiçbir** yazımı
  /// uygulanmaz (kritik asıl yazım bildirimsiz işlenmez).
  @override
  void addToBatch(
    WriteBatch batch,
    NotificationDraft draft, {
    required String recipientId,
  }) {
    final rejected =
        _rejectDraft<void>(draft) ?? _rejectRecipients<void>([recipientId]);
    if (rejected case FirebaseFailure(:final message)) {
      throw FirebaseException(
        plugin: _plugin,
        code: _invalidArgumentCode,
        message: message,
      );
    }
    batch.set(_ref(draft, recipientId), _payload(draft, recipientId));
  }

  /// Yinelenen alıcı kimlikleri tek belgeye indirgenir; dönen sayı ve
  /// [Limits.batchMaxWrites] sınırı tekil alıcılar üzerindendir.
  @override
  Future<FirestoreResult<int>> createMany(
    NotificationDraft draft,
    List<String> recipientIds,
  ) async {
    final recipients = recipientIds.toSet().toList();
    final rejected =
        _rejectDraft<int>(draft) ?? _rejectRecipients<int>(recipients);
    if (rejected != null) return rejected;
    if (recipients.isEmpty) return const FirebaseSuccess(0);
    if (recipients.length > Limits.batchMaxWrites) {
      return RepositoryHelpers.invalidArgument(
        'createMany: ${recipients.length} alıcı, sınır '
        '${Limits.batchMaxWrites}',
      );
    }
    final written = await _firestore.commitBatch((batch) {
      for (final recipientId in recipients) {
        batch.set(_ref(draft, recipientId), _payload(draft, recipientId));
      }
    });
    return written.map((_) => recipients.length);
  }

  // ── Yardımcılar ─────────────────────────────────────────────────────────

  /// Taslağı yazımdan önce doğrular: tanınmayan tür, geçersiz olay anahtarı
  /// ya da türün eksik / geçersiz zorunlu referansı için
  /// [FirestoreError.invalidArgument]; geçerliyse `null`.
  static FirestoreResult<T>? _rejectDraft<T>(NotificationDraft draft) {
    if (draft.type == NotificationType.unknown) {
      return RepositoryHelpers.invalidArgument('geçersiz tür: unknown');
    }
    if (RepositoryHelpers.rejectInvalidIds<T>({'eventKey': draft.eventKey})
        case final rejected?) {
      return rejected;
    }
    final refs = draft.refs.toJson();
    for (final field in NotificationRefsModel.requiredFor(draft.type)) {
      final value = refs[field];
      if (value is! String || !RepositoryHelpers.isValidId(value)) {
        return RepositoryHelpers.invalidArgument(
          'eksik referans: ${FirestoreFields.refs}.$field',
        );
      }
    }
    return null;
  }

  /// [recipientIds] içindeki ilk geçersiz kimlik için
  /// [FirestoreError.invalidArgument]; hepsi geçerliyse `null`.
  static FirestoreResult<T>? _rejectRecipients<T>(List<String> recipientIds) =>
      RepositoryHelpers.rejectInvalidIds<T>({
        for (final (index, id) in recipientIds.indexed)
          'recipientIds[$index]': id,
      });

  /// [draft] bildiriminin [recipientId] için yazım yükü: model alanları
  /// (`refs` yalnızca dolu referanslarla) + ortak oluşturma alanları.
  static Json _payload(NotificationDraft draft, String recipientId) => {
    ...NotificationModel(
      userId: recipientId,
      type: draft.type,
      refs: draft.refs,
    ).toJson(),
    ...BaseFieldsPayload.create(),
  };

  static NotificationModel _notificationOf(FirestoreDoc doc) =>
      NotificationModel.fromJson(doc.data, id: doc.id);

  Query<Json> get _notifications =>
      _firestore.collection(FirestoreCollections.notifications);

  /// [draft] bildiriminin [recipientId] alıcısındaki belgesi.
  DocumentReference<Json> _ref(NotificationDraft draft, String recipientId) =>
      _byId(
        FirestoreIds.notification(draft.type.json, draft.eventKey, recipientId),
      );

  DocumentReference<Json> _byId(String notificationId) =>
      _firestore.doc(FirestoreCollections.notifications, notificationId);
}
