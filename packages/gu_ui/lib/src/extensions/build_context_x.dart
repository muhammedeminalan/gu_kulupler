import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/theme/gu_theme_extension.dart';

/// `context.gu` — tema bağımlı token'lara tek erişim yolu (PLAN §7.9.1,
/// CD-18): `context.gu.colors`, `.text`, `.shadows`, `.component`, `.isDark`,
/// `.reduceMotion`, `.duration(d)`, `.textScaler`.
extension GuBuildContextX on BuildContext {
  /// Etkin temanın [GuThemeExtension] değeri.
  GuThemeExtension get gu => GuThemeExtension.of(this);
}
