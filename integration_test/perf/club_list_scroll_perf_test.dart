// T-44 · CLB-01 kaydırma ölçümü: kulüp kartları (kapak SVG'leri — R-02,
// logolar, avatar grupları) aşağı / yukarı fırlatılır. Zaman çizelgesi
// `clb01_scroll` anahtarıyla raporlanır (`test_driver/perf_driver.dart` →
// `build/clb01_scroll.timeline_summary.json`). Komut:
// `docs/reports/T-44-perf.md`.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/clubs/view/club_list_view.dart';

import 'perf_harness.dart';

void main() {
  final binding = perfBinding();

  testWidgets('CLB-01 kaydırma', (tester) async {
    await perfLaunch(tester);
    await perfEnsureClubList(tester);
    // Kartlar ve kapaklar ilk kez çözülsün (soğuk ölçüm ayrı değil).
    await tester.pump(perfFlingSettle);
    final scrollable = find
        .descendant(
          of: find.byType(ClubListView),
          matching: find.byType(Scrollable),
        )
        .first;

    await binding.traceAction(
      () => perfFlingDownUp(tester, scrollable),
      reportKey: 'clb01_scroll',
    );
  });
}
