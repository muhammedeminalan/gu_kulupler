import 'package:flutter/widgets.dart';
import 'package:gu_ui/gu_ui.dart';

/// NTF-01 gün grubu — `.group-head .t-overline` başlığı (sayaçsız) +
/// `NotificationRow` satırları (`screens-events.js:105`).
///
/// Sliver'dır (`CustomScrollView` içinde): başlık grubun içinde yapışkandır
/// (`.group-head{position:sticky}` — kendi grubu görünürken üstte kalır,
/// sonraki grubun başlığı onu iter; `SliverMainAxisGroup`). Başlık
/// çağırandan ("Bugün" / "Dün" / "Bu hafta" / "Daha önce"), yerel büyük
/// harfle çizilir (`text-transform: uppercase`); satırlar [children]
/// (çağıran `NotificationRow` kurar; anahtarları o verir).
class NotificationGroup extends StatelessWidget {
  /// [title] başlıklı [children] satırları.
  const NotificationGroup({
    required this.title,
    required this.children,
    super.key,
  });

  /// Grup başlığı.
  final String title;

  /// Grubun satırları (en yeni üstte).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      GuGroupHeader(
        title: title.upperFor(Localizations.localeOf(context)),
        sticky: true,
      ),
      SliverList.list(children: children),
    ],
  );
}
