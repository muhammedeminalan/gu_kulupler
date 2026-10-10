import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Liste sonu satırı — prototip `ListEnd` (`ui.js:123`), CSS `.center` +
/// `.t-caption` (css:99, 96) ve satır içi dolgu `20px 16px 8px`.
///
/// Ortalı caption (`text.muted`): `— {label} —`. Tireler dekoratiftir,
/// [label] çağırandan gelir (ARB `commonAllDone`); ekran okuyucu yalnızca
/// [label]'ı okur.
class GuListEnd extends StatelessWidget {
  const GuListEnd({required this.label, super.key});

  /// Satır metni (tiresiz).
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: GuInsets.only(
      left: GuSizes.listEndPaddingX,
      top: GuSizes.listEndPaddingTop,
      right: GuSizes.listEndPaddingX,
      bottom: GuSizes.listEndPaddingBottom,
    ),
    child: Center(
      heightFactor: 1,
      child: Text(
        '— $label —',
        style: context.gu.text.caption,
        textAlign: TextAlign.center,
        semanticsLabel: label,
      ),
    ),
  );
}
