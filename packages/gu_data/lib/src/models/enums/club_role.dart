import 'package:collection/collection.dart';
import 'package:gu_data/src/constants/role_codes.dart';
import 'package:json_annotation/json_annotation.dart';

/// Kulüp bazlı rol (`memberships.role`; PLAN §9.7, domain-model §3).
///
/// Yalnızca üyelik `active` iken anlamlıdır. Süper admin bir kulüp rolü
/// değildir (global claim, [RoleCodes.superadmin]) ve bu enum'un dışındadır.
/// Enum'un **tek** tanımı bu dosyadır.
@JsonEnum(valueField: 'json')
enum ClubRole {
  /// Sıradan üye.
  member(RoleCodes.member),

  /// Yönetim kurulu üyesi (yönetici).
  board(RoleCodes.board),

  /// Kulüp başkanı (yönetici).
  president(RoleCodes.president),

  /// Danışman (yönetim panelinde salt okunur).
  advisor(RoleCodes.advisor);

  const ClubRole(this.json);

  /// Firestore'daki dizgi karşılığı ([RoleCodes]).
  final String json;

  /// Firestore dizgisinden rol üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer — [RoleCodes.superadmin] dahil — [ArgumentError] fırlatır; bu
  /// enum'da `unknown` üyesi yoktur.
  static ClubRole fromJson(String json) =>
      values.firstWhereOrNull((role) => role.json == json) ??
      (throw ArgumentError.value(
        json,
        'json',
        'ClubRole: bilinmeyen rol kodu',
      ));
}
