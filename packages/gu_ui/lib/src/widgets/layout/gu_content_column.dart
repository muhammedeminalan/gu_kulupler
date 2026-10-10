import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/tokens/gu_breakpoints.dart';

/// İçerik sütunu (Q-13, CD-29) — tasarımda karşılığı yoktur: prototip 390 px
/// sabit cihazdır (`.device`, css:112).
///
/// Ekran `GuBreakpoints.maxContentWidth`'ten (480) genişse [child] ortalanmış
/// 480 dp sütuna alınır (`Center` + `ConstrainedBox`); 480 ve altında [child]
/// olduğu gibi döner (ek kutu yok). Sütun dışı zemin (`bg.canvas`) kabuğa
/// aittir.
///
/// `GuApp.builder` gövdeyi (T-11), `GuSheetFrame` / `GuDialogFrame` /
/// `GuToast` kendini sarar (T-07); `GuBottomNav` ve `GuAppBar` tam genişlik
/// kalır. Genişlik parametresi yoktur (tek sabit).
class GuContentColumn extends StatelessWidget {
  const GuContentColumn({required this.child, super.key});

  /// Sütuna alınacak içerik.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!GuBreakpoints.isWide(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: GuBreakpoints.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
