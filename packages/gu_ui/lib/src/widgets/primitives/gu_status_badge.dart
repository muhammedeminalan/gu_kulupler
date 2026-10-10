import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/widgets/primitives/gu_badge.dart';

/// Durum rozeti türü — prototip `STATUS_BADGE` (`ui.js:65` =
/// `registry.json#statusBadge`, 21 durum; sıra kayıtla aynı): rozet sınıfı +
/// ikon. Kayıttaki `void` Dart'ta ayrılmış sözcük olduğundan üye adı
/// [voided]'dir.
enum GuStatusBadgeKind {
  /// `badge-pending` + `hourglass`.
  pending(GuBadgeKind.pending, GuIcons.hourglass),

  /// `badge-success` + `circle-check`.
  approved(GuBadgeKind.success, GuIcons.circleCheck),

  /// `badge-success` + `circle-check`.
  going(GuBadgeKind.success, GuIcons.circleCheck),

  /// `badge-success` + `circle-check`.
  attended(GuBadgeKind.success, GuIcons.circleCheck),

  /// `badge-success` + `circle-check`.
  active(GuBadgeKind.success, GuIcons.circleCheck),

  /// `badge-danger` + `circle-x`.
  rejected(GuBadgeKind.danger, GuIcons.circleX),

  /// `badge-danger` + `circle-x`.
  cancelled(GuBadgeKind.danger, GuIcons.circleX),

  /// `badge-danger` + `user-x`.
  removed(GuBadgeKind.danger, GuIcons.userX),

  /// `badge-neutral` + `circle-x`.
  absent(GuBadgeKind.neutral, GuIcons.circleX),

  /// `badge-full` + `users`.
  full(GuBadgeKind.full, GuIcons.users),

  /// `badge-pending` + `hourglass`.
  waitlist(GuBadgeKind.pending, GuIcons.hourglass),

  /// `badge-neutral` + `lock`.
  members(GuBadgeKind.neutral, GuIcons.lock),

  /// `badge-neutral` + `file-text`.
  draft(GuBadgeKind.neutral, GuIcons.fileText),

  /// `badge-success` + `circle-check`.
  published(GuBadgeKind.success, GuIcons.circleCheck),

  /// `badge-danger` + `ban`.
  suspended(GuBadgeKind.danger, GuIcons.ban),

  /// `badge-neutral` + `history`.
  past(GuBadgeKind.neutral, GuIcons.history),

  /// `badge-pending` + `flag`.
  open(GuBadgeKind.pending, GuIcons.flag),

  /// `badge-success` + `circle-check`.
  resolved(GuBadgeKind.success, GuIcons.circleCheck),

  /// `badge-success` + `circle-check`.
  valid(GuBadgeKind.success, GuIcons.circleCheck),

  /// `badge-neutral` + `check-check`.
  used(GuBadgeKind.neutral, GuIcons.checkCheck),

  /// `badge-danger` + `circle-x` (kayıt anahtarı `void`).
  voided(GuBadgeKind.danger, GuIcons.circleX);

  const GuStatusBadgeKind(this.badgeKind, this.icon);

  /// Rozet gövdesinin renk türü (CSS `.badge-*`, css:194–198).
  final GuBadgeKind badgeKind;

  /// Durum ikonu (12 px).
  final GuIcons icon;
}

/// Durum rozeti — prototip `StatusBadge` (`ui.js:68`), CSS `.badge` +
/// `.badge-success/-danger/-pending/-neutral/-full` (css:188, 194–198).
/// Kendi gövdesi yoktur: [GuBadge]'i türün rengi ve ikonu ile sarar (CD-27).
///
/// Metin (`status.<id>` ya da geçersiz kılınmış etiket: MGT-06
/// "Katıldın / Kayıtlı", ADM-05 rol adı) çağırandan gelir. Prototipteki
/// "bilinmeyen durum → neutral + `info`" dalı enum ile gereksizdir; alan
/// durumu → tür eşlemesi ürün katmanındadır (T-16).
class GuStatusBadge extends StatelessWidget {
  const GuStatusBadge({required this.kind, required this.label, super.key});

  /// Durum türü (renk + ikon).
  final GuStatusBadgeKind kind;

  /// Durum metni (çağıran ARB'den verir).
  final String label;

  @override
  Widget build(BuildContext context) =>
      GuBadge(label: label, kind: kind.badgeKind, icon: kind.icon);
}
