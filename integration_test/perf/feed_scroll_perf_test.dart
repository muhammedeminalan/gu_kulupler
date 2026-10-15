// T-44 · FED-01 akış kaydırma ölçümü: CLB-03 "Gönderiler" sekmesi (`c01`,
// demo üyenin kulübü) aşağı / yukarı fırlatılır — tembel liste (P1-01),
// gönderi görselleri ve kapak SVG'leri. Zaman çizelgesi `fed01_scroll`
// anahtarıyla raporlanır (`build/fed01_scroll.timeline_summary.json`).
//
// Seed'de `c01` akışı 7 gönderidir: ölçüm kısa listede kare maliyetini
// gösterir; uzun liste için emülatörde gönderi eklenip yeniden koşulur.
// Komut: `docs/reports/T-44-perf.md`.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_feed_tab.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

import 'perf_harness.dart';

/// Demo üyenin etkin üyesi olduğu kulüp (seed `memberships`).
const String _clubId = 'c01';

void main() {
  final binding = perfBinding();

  testWidgets('FED-01 akış kaydırma', (tester) async {
    await perfLaunch(tester);
    await perfEnsureClubList(tester);
    await perfTap(tester, GuKey.action('CLB-01.card.$_clubId'));
    await perfTap(tester, GuKey.action('CLB-03.tab.posts'));
    await perfWaitFor(tester, find.byType(ClubFeedTab));
    await perfWaitFor(tester, find.byType(PostCard));
    await tester.pump(perfFlingSettle);
    final scrollable = find
        .descendant(
          of: find.byType(ClubDetailView),
          matching: find.byType(Scrollable),
        )
        .first;

    await binding.traceAction(
      () => perfFlingDownUp(tester, scrollable),
      reportKey: 'fed01_scroll',
    );
  });
}
