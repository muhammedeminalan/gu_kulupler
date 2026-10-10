import 'package:collection/collection.dart';
import 'package:gu_data/src/constants/role_codes.dart';
import 'package:json_annotation/json_annotation.dart';

/// Üyelik durumu (`memberships.status`; PLAN §9.7, domain-model §2.4, §5).
///
/// `none` bir üye değildir: belge yoktur ya da durum [left] / [cancelled]'dır.
/// Dizgiler [MembershipStatusCodes] sabitlerinden okunur.
@JsonEnum(valueField: 'json')
enum MembershipStatus {
  /// Başvuru karar bekliyor.
  pending(MembershipStatusCodes.pending),

  /// Aktif üye (rol yalnızca bu durumda anlamlıdır).
  active(MembershipStatusCodes.active),

  /// Başvuru reddedildi (`retryAfter` dolana kadar yeniden başvuramaz).
  rejected(MembershipStatusCodes.rejected),

  /// Üye kulüpten çıkarıldı (`retryAfter` dolana kadar yeniden başvuramaz).
  removed(MembershipStatusCodes.removed),

  /// Üye kendi isteğiyle ayrıldı.
  left(MembershipStatusCodes.left),

  /// Başvuran isteğini geri çekti.
  cancelled(MembershipStatusCodes.cancelled);

  const MembershipStatus(this.json);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// Firestore dizgisinden değer üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer [ArgumentError] fırlatır; bu enum'da `unknown` üyesi yoktur
  /// (model ayrıştırmasında `CheckedFromJsonException` →
  /// `FirestoreError.parse`).
  static MembershipStatus fromJson(String json) =>
      values.firstWhereOrNull((value) => value.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'MembershipStatus: bilinmeyen değer',
      ));
}
