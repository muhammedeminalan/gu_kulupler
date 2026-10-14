import 'dart:math';

import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/storage_paths.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/storage_error.dart';
import 'package:gu_data/src/models/enums/support_subject.dart';
import 'package:gu_data/src/models/support_attachment.dart';
import 'package:gu_data/src/models/support_ticket_model.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/support_repository.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/storage_service.dart';
import 'package:gu_data/src/utils/field_validators.dart';
import 'package:gu_data/src/utils/ticket_code.dart';

/// [SupportRepository] uygulaması: `supportTickets/{ticketNo}` ve
/// `support/{ticketNo}/{file}` ekleri (PLAN §10.4; rules-spec §3.15, §7).
///
/// **Belge kimliği talep numarasıdır** (`supportTickets/GU-XXXXXX`;
/// `ticketNo` alanı da yazılır, Rules ikisinin eşitliğini ister). Numara
/// 30 bit rastgeledir: tekilliği Security Rules sağlar — var olan numaraya
/// yazım `create` değil `update` sayılır ve talep sahibine kapalıdır
/// (`permission-denied`). Bu ret alınınca talep **bir kez** yeni numarayla
/// (ek varsa yeni klasöre yeniden yüklenerek) baştan yazılır; ikinci sonuç
/// nihaidir. Böylece ek klasörü (`support/{ticketNo}/`) de tek talebe aittir.
final class FirebaseSupportRepository implements SupportRepository {
  /// [_firestore] üzerinden okur ve yazar; eki [_storage] ile yükler. Talep
  /// numarası [_codes] üreticisinden (kompozisyon kökü
  /// `SecureTicketCodeGenerator` verir), ek dosya adının damgası [_clock]
  /// saatinden, rastgele kısmı [_random] kaynağından gelir (kök
  /// `Random.secure()` verir).
  FirebaseSupportRepository(
    this._firestore,
    this._storage,
    this._codes,
    this._clock,
    this._random,
  );

  final FirestoreService _firestore;
  final StorageService _storage;
  final TicketCodeGenerator _codes;
  final AppClock _clock;
  final Random _random;

  /// Ek nesnesinin tek özel üst verisi: yükleyenin `uid`'i (Storage Rules
  /// `metadata.keys().hasOnly(['uploaderId', jeton])` ve
  /// `metadata.uploaderId == request.auth.uid`; okumayı da bu alan açar —
  /// yalnızca yükleyen ve süper admin okur).
  static const String _uploaderIdMetadata = 'uploaderId';

  @override
  Future<MediaUpdateResult<SupportTicketModel>> createTicket({
    required String userId,
    required SupportSubject subject,
    required String message,
    SupportAttachment? attachment,
  }) async {
    if (_reject(userId, message, attachment) case final rejected?) {
      return rejected;
    }
    final first = await _write(userId, subject, message, attachment);
    // Numara çakışması Rules'ta `permission-denied`dır (var olan belgeye
    // yazım = update). Ret başka bir nedenden de gelebilir (profili
    // tamamlanmamış hesap): ikinci deneme de aynı sonucu verir ve nihaidir.
    if (first case FirebaseFailure(
      error: MediaDocumentError(error: FirestoreError.permissionDenied),
    )) {
      return _write(userId, subject, message, attachment);
    }
    return first;
  }

  @override
  Future<FirestoreResult<List<SupportTicketModel>>> listMine(
    String userId,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<List<SupportTicketModel>>({
          'userId': userId,
        })
        case final rejected?) {
      return rejected;
    }
    // Sorgu sözleşmesi (rules-spec §6, §8): sahibi + `createdAt` ↓. Talepler
    // soft delete edilmez; indeks `isDeleted` içermez — süzgeç istemcide.
    final result = RepositoryHelpers.parseAll(
      await _firestore.getList(
        _firestore
            .collection(FirestoreCollections.supportTickets)
            .where(FirestoreFields.userId, isEqualTo: userId)
            .orderBy(FirestoreFields.createdAt, descending: true),
      ),
      (doc) => SupportTicketModel.fromJson(doc.data, id: doc.id),
    );
    return result.map(
      (tickets) => [
        for (final ticket in tickets)
          if (!ticket.isDeleted) ticket,
      ],
    );
  }

  /// Tek deneme: yeni numara → (ek varsa) yükleme → belge yazımı.
  Future<MediaUpdateResult<SupportTicketModel>> _write(
    String userId,
    SupportSubject subject,
    String message,
    SupportAttachment? attachment,
  ) async {
    final ticketNo = _codes.supportTicketNo();
    final paths = <String>[];
    if (attachment != null) {
      // Ön denetim türü doğruladı: uzantı içerik türünden gelir.
      final extension =
          StoragePaths.extensionByContentType[attachment.contentType]!;
      final uploaded = await _storage.upload(
        path: StoragePaths.supportAttachment(
          ticketNo,
          StoragePaths.newFileName(_clock, _random, extension),
        ),
        bytes: attachment.bytes,
        contentType: attachment.contentType,
        customMetadata: {_uploaderIdMetadata: userId},
      );
      switch (uploaded) {
        case FirebaseFailure(:final error, :final message):
          return FirebaseFailure(MediaUploadError(error), message: message);
        case FirebaseSuccess(data: final path):
          paths.add(path);
      }
    }

    final ticket = SupportTicketModel(
      ticketNo: ticketNo,
      userId: userId,
      subject: subject,
      message: message,
      attachmentPaths: paths,
    );
    final written = await _firestore.set(
      _firestore.doc(FirestoreCollections.supportTickets, ticketNo),
      {...ticket.toJson(), ...BaseFieldsPayload.create()},
    );
    switch (written) {
      case FirebaseFailure(:final error, :final message):
        // Yüklenen ek yerinde kalır (D-10: dosya silinmez).
        return FirebaseFailure(MediaDocumentError(error), message: message);
      case FirebaseSuccess():
        // Sunucu zamanı yazım anında okunamaz: zaman alanları yaklaşıktır.
        final now = _clock.nowUtc();
        return FirebaseSuccess(
          ticket.copyWith(id: ticketNo, createdAt: now, updatedAt: now),
        );
    }
  }

  /// Ön denetim; sorun yoksa `null`. Önce çağrının kendisi (kimlik, mesaj —
  /// belge hatası), sonra ekin baytları (tür → boş → boyut sınırı —
  /// yükleme hatası); `StorageService.upload` ile aynı koşullar, ağ
  /// çağrısından önce.
  static MediaUpdateResult<SupportTicketModel>? _reject(
    String userId,
    String message,
    SupportAttachment? attachment,
  ) {
    final invalid =
        RepositoryHelpers.rejectInvalidIds<void>({'userId': userId}) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          FirestoreFields.message: FieldValidators.supportMessage(message),
        });
    if (invalid case FirebaseFailure(:final error, :final message)) {
      return FirebaseFailure(MediaDocumentError(error), message: message);
    }
    if (attachment == null) return null;
    final StorageError? error;
    if (!StoragePaths.extensionByContentType.containsKey(
      attachment.contentType,
    )) {
      error = StorageError.invalidType;
    } else if (attachment.bytes.isEmpty) {
      error = StorageError.noFile;
    } else if (attachment.bytes.length >= Limits.imageMaxBytes) {
      // Storage Rules `size < imageMaxBytes` ister: sınırın kendisi de ret.
      error = StorageError.sizeLimit;
    } else {
      error = null;
    }
    return error == null ? null : FirebaseFailure(MediaUploadError(error));
  }
}
