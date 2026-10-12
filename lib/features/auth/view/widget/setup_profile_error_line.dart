import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// Alana bağlı olmayan hata satırı — CSS `.field-help.is-error` (css:171):
/// `triangle-alert` 14 + `state.danger` metin, aralık 4; `role="alert"` →
/// `Semantics(liveRegion)`.
///
/// AUT-05'te ilgi alanı çiplerinin altında (`screens-auth.js:145`) ve
/// fotoğraf / gönderim hatalarında kullanılır; kutulu alanların hatası
/// `GuField` içindedir.
class SetupProfileErrorLine extends StatelessWidget {
  /// [text] hata metniyle.
  const SetupProfileErrorLine(this.text, {super.key});

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
