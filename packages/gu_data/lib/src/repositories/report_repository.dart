import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/enums/report_reason.dart';
import 'package:gu_data/src/models/enums/report_target_type.dart';

/// Şikayet edilen şey (PLAN §10.4, CD-33): türü, kimliği ve ait olduğu kulüp.
///
/// `clubId` hedefin kulübüdür: `post` ⇒ gönderinin, `comment` ⇒ yorumun,
/// `event` ⇒ etkinliğin kulübü; `club` hedefinde `id` ile aynıdır; `user`
/// hedefinde `null`'dır. Kayıt (record) tipidir: değer eşitliği taşır,
/// `ReportViewModel` ailesinin parametresi olarak kullanılır.
typedef ReportTarget = ({ReportTargetType type, String id, String? clubId});

/// Şikayetler — `reports/{reporterId}_{targetType}_{targetId}` (PLAN §10.4;
/// rules-spec §3.10; CD-33).
///
/// Her kullanıcı bir hedefi **yalnızca bir kez** şikayet edebilir: belge
/// kimliği şikayet eden + hedeften türer. Şikayeti yalnızca sahibi ve süper
/// admin okur; listeleme ve çözme `AdminRepository` işidir. Kimlik
/// parametreleri dış girdi sayılır: geçersiz kimlik (boş, `/` içeren)
/// [FirestoreError.invalidArgument] döner. Belge silme yoktur (D-10).
abstract interface class ReportRepository {
  /// [reporterId] kullanıcısının [target] için [reason] nedenli şikayetini
  /// oluşturur (`status: open`); [note] isteğe bağlı açıklamadır
  /// (≤ `Limits.reportNoteMax`).
  ///
  /// Yazmadan [FirestoreError.invalidArgument] dönen durumlar: kullanıcının
  /// kendini şikayet etmesi, `user` hedefinde kulüp verilmesi, `post` /
  /// `comment` / `club` / `event` hedefinde kulübün eksik olması, `club`
  /// hedefinde kulübün hedefle aynı olmaması, uzun not. `other` nedeninde
  /// notun zorunluluğu formun işidir.
  ///
  /// Aynı hedef daha önce şikayet edilmişse [FirestoreError.alreadyExists]
  /// döner ve var olan şikayet değişmez (SHT-10 "zaten bildirdin"). Çağıran
  /// etkin (doğrulanmış, profili tamam, askıda olmayan) kullanıcıdır; aksi
  /// halde [FirestoreError.permissionDenied].
  Future<FirestoreResult<void>> report({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    String note = '',
  });

  /// [reporterId] kullanıcısı [target] hedefini daha önce şikayet etti mi?
  ///
  /// Çözülmüş şikayet de sayılır (aynı hedef yeniden şikayet edilemez).
  /// Yalnızca hedefin türü ve kimliği kullanılır; `clubId` okunmaz.
  Future<FirestoreResult<bool>> hasReported({
    required String reporterId,
    required ReportTarget target,
  });
}
