import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// Alana bağlı olmayan hata satırı — CSS `.field-help.is-error` (css:171):
/// `triangle-alert` 14 + `state.danger` metin, aralık 4; `role="alert"` →
/// `Semantics(liveRegion)`.
///
/// Kutusuz form parçalarının (çip grubu, avatar, gönderim) hatası: AUT-05
/// ilgi alanı çiplerinin altında (`screens-auth.js:145`) ve fotoğraf /
/// gönderim hatalarında, PRF-02 ilgi alanları / fotoğraf / gönderim
/// hatalarında (`screens-profile.js:29`). Kutulu alanların hatası `GuField`
/// içindedir. T-27'de `features/auth`'tan product'a taşındı (eski adı
/// `SetupProfileErrorLine`).
class FormErrorLine extends StatelessWidget {
  /// [text] hata metniyle.
  const FormErrorLine(this.text, {super.key});

  /// Hata metni (çağırandan; ARB).
  final String text;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final danger = gu.colors.stateDanger;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSizes.fieldHelpGap,
        children: [
          GuIcon(
            GuIcons.triangleAlert,
            size: GuSizes.fieldHelpIcon,
            color: danger,
          ),
          Expanded(
            child: Text(text, style: gu.text.fieldHelp.copyWith(color: danger)),
          ),
        ],
      ),
    );
  }
}
