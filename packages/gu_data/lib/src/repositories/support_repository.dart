import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/models/enums/support_subject.dart';
import 'package:gu_data/src/models/support_attachment.dart';
import 'package:gu_data/src/models/support_ticket_model.dart';

/// Destek talepleri — `supportTickets/{ticketNo}` ve ekleri
/// `support/{ticketNo}/{file}` (PLAN §10.4; rules-spec §3.15, §7).
///
/// Talebi yalnızca sahibi oluşturur; sahibi ve süper admin okur, yalnızca
/// süper admin kapatır (`status`). **Belge ve dosya silme yoktur (D-10).**
/// Yetki arayüzde değil Security Rules'ta uygulanır: yetkisiz çağrı
/// [FirestoreError.permissionDenied] döner. Kimlik parametreleri dış girdi
/// sayılır: geçersiz kimlik (boş, `/` içeren) [FirestoreError.invalidArgument]
/// döner.
abstract interface class SupportRepository {
  /// [userId] adına [subject] konulu, [message] mesajlı yeni destek talebi
  /// açar ve yazılan modeli döner (`ticketNo` → TST-23 `#GU-XXXXXX`).
  ///
  /// * Talep numarası `TicketCodeGenerator.supportTicketNo()` ile üretilir
  ///   (kriptografik kaynak, `FirestoreIds.supportTicketNoPattern`); belge
  ///   kimliği numaranın kendisidir (`supportTickets/{ticketNo}`; `ticketNo`
  ///   alanı da yazılır). Var olan numara Rules'ta reddedilir
  ///   (`permission-denied`): talep bir kez yeni numarayla yeniden yazılır.
  /// * [attachment] verilirse **önce** Storage'a yüklenir:
  ///   `StoragePaths.supportAttachment(ticketNo, StoragePaths.newFileName(…))`,
  ///   `customMetadata: {'uploaderId': userId}` (sabit ad yok, üzerine yazma
  ///   yok); ardından belge `attachmentPaths = [yüklenen yol]` ile yazılır
  ///   (en çok `Limits.supportAttachmentsMax` = 1).
  /// * Belge `status: open` ile yazılır; zaman alanları sunucu zamanıdır,
  ///   dönen modeldeki değerler istemci saatinden yaklaşıktır.
  ///
  /// Hatalar (hangi adımdaysa onu taşır):
  /// - geçersiz [userId], boş ya da `Limits.supportMessageMax` (500)
  ///   karakterden uzun [message] → [MediaDocumentError]
  ///   ([FirestoreError.invalidArgument]; hiçbir şey gönderilmez);
  /// - ek: izinsiz tür → [MediaUploadError] (`StorageError.invalidType`),
  ///   boş bayt → `StorageError.noFile`, `Limits.imageMaxBytes` (5 MB)
  ///   sınırında ya da üstünde → `StorageError.sizeLimit` (dosya
  ///   gönderilmeden); yükleme reddi / ağ → [MediaUploadError] (belge
  ///   yazılmaz);
  /// - belge yazımı → [MediaDocumentError]; yüklenen ek yerinde kalır
  ///   (silinmez), yeniden deneme yeni numara ve yeni dosya adı üretir.
  Future<MediaUpdateResult<SupportTicketModel>> createTicket({
    required String userId,
    required SupportSubject subject,
    required String message,
    SupportAttachment? attachment,
  });

  /// [userId] kullanıcısının silinmemiş talepleri, en yeni önce
  /// (`userId ==`, `createdAt` ↓; indeks rules-spec §8). Tek bir kayıt bile
  /// modele çevrilemezse [FirestoreError.parse].
  Future<FirestoreResult<List<SupportTicketModel>>> listMine(String userId);
}
