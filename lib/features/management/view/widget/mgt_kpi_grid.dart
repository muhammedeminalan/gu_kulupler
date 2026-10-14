import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-01 gösterge ızgarası — prototip `.grid2` (`screens-manage.js:24`):
/// iki sütun, aralık 12; aynı satırdaki kartlar eşit boya gerilir
/// (`IntrinsicHeight` + `Row(stretch)`, `GuKpi` notu G14 / CD-112).
///
/// Kartlar (`GuKpi`, anahtarlarıyla) çağırandan gelir. Hızlı işlemler
/// (`.grid3`, `screens-manage.js:25`) aynı ızgarayı [columnCount] 3 ile
/// kullanır.
class MgtKpiGrid extends StatelessWidget {
  /// [children] kartlarının ızgarası.
  const MgtKpiGrid({
    required this.children,
    this.columnCount = columns,
    super.key,
  });

  /// Varsayılan sütun sayısı (`.grid2`).
  static const int columns = 2;

  /// Kartlar (soldan sağa, yukarıdan aşağıya).
  final List<Widget> children;

  /// Sütun sayısı (`.grid2` 2, `.grid3` 3).
  final int columnCount;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: GuSpacing.s12,
    children: [
      for (var start = 0; start < children.length; start += columnCount)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSpacing.s12,
            children: [
              for (var i = start; i < start + columnCount; i++)
                Expanded(
                  child: i < children.length
                      ? children[i]
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
    ],
  );
}
