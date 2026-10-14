// `SupportRepository` fake'i (PLAN §16.3): destek taleplerini ve ekleri
// bellekte tutar.
//
//   final support = FakeSupportRepository(clock);
//   final result = await support.createTicket(
//     userId: 'u1',
//     subject: SupportSubject.bug,
//     message: 'Uygulama açılmıyor',
//   );
//   expect(result.dataOrNull?.ticketNo, 'GU-AAAAAB');
//
// Gerçek repository gibi: ön denetim (kimlik / mesaj →
// `MediaDocumentError(invalidArgument)`; ek türü / boş / boyut →
// `MediaUploadError`) hiçbir şey "göndermeden" döner; ek önce "yüklenir"
// ([attachments]), sonra belge yazılır. `failNext(StorageError.x)` yüklemeyi
// keser (belge yazılmaz); `failNext(FirestoreError.x)` belge adımında düşer
// (ek verildiyse yüklenmiş kalır — D-10). Talep numaraları sıralıdır ve
// `FirestoreIds.supportTicketNoPattern` ile eşleşir (`GU-AAAAAB`,
// `GU-AAAAAC`, …); [ticketNoQueue] doluysa sıradaki oradan alınır.
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

/// [FakeSupportRepository.createTicket] ile "yüklenen" tek ek: talep
/// numarası, üst verideki yükleyen (`customMetadata.uploaderId`), gönderilen
/// girdi ve Storage yolu.
typedef FakeSupportUpload = ({
  String ticketNo,
  String uploaderId,
  SupportAttachment attachment,
  String path,
});

final class FakeSupportRepository extends FakeBase
    implements SupportRepository {
  /// "Şu an" [_clock] saatidir (`createdAt`, `updatedAt`).
  FakeSupportRepository(this._clock);

  final AppClock _clock;

  /// `supportTickets/{id}` belgeleri (anahtar = belge kimliği). Test ön
  /// veriyi [put] ile yazar.
  final Map<String, SupportTicketModel> tickets =
      <String, SupportTicketModel>{};

  /// Yüklenen ekler, yükleme sırasıyla (belge adımı düşen çağrınınki dahil).
  final List<FakeSupportUpload> attachments = <FakeSupportUpload>[];

  /// [createTicket] sıradaki numarayı buradan alır; boşsa sıralı üretir.
  final List<String> ticketNoQueue = <String>[];

  int _ticketSerial = 0;
  int _docSerial = 0;
  int _fileSerial = 0;

  /// [ticket] belgesini yazar. Gerçek repository gibi belge kimliği talep
  /// numarasıdır (`supportTickets/{ticketNo}`); kimlik ve numara boşsa
  /// `st_fake_N` verilir.
  SupportTicketModel put(SupportTicketModel ticket) {
    final stored = ticket.id.isNotEmpty
        ? ticket
        : ticket.copyWith(
            id: ticket.ticketNo.isNotEmpty ? ticket.ticketNo : _nextDocId(),
          );
    tickets[stored.id] = stored;
    return stored;
  }

  @override
  Future<MediaUpdateResult<SupportTicketModel>> createTicket({
    required String userId,
    required SupportSubject subject,
    required String message,
    SupportAttachment? attachment,
  }) async {
    record('createTicket', [userId, subject, message, attachment]);
    final injected = takeFailure();
    if (!RepositoryHelpers.isValidId(userId) ||
        FieldValidators.supportMessage(message) != null) {
      return _documentFailure(FirestoreError.invalidArgument);
    }
    if (attachment != null) {
      if (!StoragePaths.extensionByContentType.containsKey(
        attachment.contentType,
      )) {
        return _uploadFailure(StorageError.invalidType);
      }
      if (attachment.bytes.isEmpty) return _uploadFailure(StorageError.noFile);
      if (attachment.bytes.length >= Limits.imageMaxBytes) {
        return _uploadFailure(StorageError.sizeLimit);
      }
    }
    final ticketNo = ticketNoQueue.isNotEmpty
        ? ticketNoQueue.removeAt(0)
        : _nextTicketNo();
    final paths = <String>[];
    if (attachment != null) {
      if (injected is StorageError) return _uploadFailure(injected);
      final path = StoragePaths.supportAttachment(
        ticketNo,
        _nextFileName(
          StoragePaths.extensionByContentType[attachment.contentType]!,
        ),
      );
      attachments.add((
        ticketNo: ticketNo,
        uploaderId: userId,
        attachment: attachment,
        path: path,
      ));
      paths.add(path);
    }
    if (injected is FirestoreError) return _documentFailure(injected);
    if (injected != null) return _documentFailure(FirestoreError.unknown);
    final now = _clock.nowUtc();
    final ticket = put(
      SupportTicketModel(
        ticketNo: ticketNo,
        userId: userId,
        subject: subject,
        message: message,
        attachmentPaths: paths,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return FirebaseSuccess(ticket);
  }

  @override
  Future<FirestoreResult<List<SupportTicketModel>>> listMine(
    String userId,
  ) async {
    record('listMine', [userId]);
    if (takeFailure() case final error?) {
      return FirebaseFailure(
        error is FirestoreError ? error : FirestoreError.unknown,
      );
    }
    if (!RepositoryHelpers.isValidId(userId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final mine = [
      for (final ticket in tickets.values)
        if (ticket.userId == userId && !ticket.isDeleted) ticket,
    ]..sort((a, b) => _instant(b).compareTo(_instant(a)));
    return FirebaseSuccess(mine);
  }

  static DateTime _instant(SupportTicketModel ticket) =>
      ticket.createdAt ?? DateTime.utc(0);

  String _nextDocId() => 'st_fake_${++_docSerial}';

  /// `GU-` + sıra numarasının alfabe tabanında (32'lik) 6 karakteri;
  /// `A` sıfırdır (gu_data `FakeTicketCodeGenerator.supportTicketNoAt`).
  String _nextTicketNo() {
    const alphabet = TicketCodeGenerator.alphabet;
    var n = ++_ticketSerial;
    final chars = List.filled(6, alphabet[0]);
    for (var i = chars.length - 1; i >= 0 && n > 0; i--) {
      chars[i] = alphabet[n % alphabet.length];
      n ~/= alphabet.length;
    }
    return 'GU-${chars.join()}';
  }

  String _nextFileName(String extension) {
    final serial = (++_fileSerial).toRadixString(16).padLeft(16, '0');
    return '20261014T090000Z_$serial.$extension';
  }

  static MediaUpdateResult<SupportTicketModel> _uploadFailure(
    StorageError error,
  ) => FirebaseFailure(MediaUploadError(error));

  static MediaUpdateResult<SupportTicketModel> _documentFailure(
    FirestoreError error,
  ) => FirebaseFailure(MediaDocumentError(error));
}
