import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';

/// Sayaç rozetinin metni (CD-81): `0` → rozet yok (`null`),
/// `1…Limits.unreadBadgeMax` → sayı, üstü → `9+` (ARB `badgeOverflow`).
///
/// Sınır yalnızca alt sekme ve ikon düğme rozetinde uygulanır (`shell.js:12`,
/// `ui.js:19`); çip ve sekme sayaçları ham sayıyı gösterir.
String? countBadgeLabel(AppLocalizations l10n, int count) {
  if (count <= 0) return null;
  return count > Limits.unreadBadgeMax ? l10n.badgeOverflow : '$count';
}
