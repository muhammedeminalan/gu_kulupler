import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import 'pump_app.dart';
import 'semantics_scan.dart';

/// Kasıtlı kusurlu çubuk: `tabBar` düğümü 8 px alt dolguyu kapsar, sekme
/// kapsamaz → önbellek kenarı dolguya düştüğünde çubuk boş kalır.
Widget _faultyBar() => Semantics(
  role: SemanticsRole.tabBar,
  container: true,
  explicitChildNodes: true,
  child: Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      role: SemanticsRole.tab,
      container: true,
      selected: true,
      onTap: () {},
      label: 'Sekme',
      child: const SizedBox(height: 40),
    ),
  ),
);

Widget _list(Widget bar) => ListView(
  children: [
    const SizedBox(height: 1200),
    bar,
    const SizedBox(height: 2000),
  ],
);

void main() {
  group('T-02 · expectSemanticsCleanWhileScrolling', () {
    testWidgets('kusurlu tabBar: önbellek kenarı dolguya düşünce TestFailure '
        '(konum + "a TabBar cannot be empty")', (tester) async {
      Object? failure;
      try {
        await expectSemanticsCleanWhileScrolling(
          tester,
          (platform) => tester.pumpApp(_list(_faultyBar()), platform: platform),
          platforms: const [TargetPlatform.android],
          maxDistance: 1600,
        );
      } on TestFailure catch (error) {
        failure = error;
      }
      expect(failure, isA<TestFailure>());
      expect('$failure', contains('a TabBar cannot be empty'));
      expect('$failure', contains('android #0 @'));
      // Hatalı karelerin kalıntısı sonraki testlere taşınmaz.
      await tester.pumpWidget(const SizedBox.shrink());
      tester.takeException();
    });

    testWidgets('GuTabs + GuSegmented listede: iOS + Android tarama temiz', (
      tester,
    ) async {
      await expectSemanticsCleanWhileScrolling(
        tester,
        (platform) => tester.pumpApp(
          _list(
            Column(
              children: [
                GuTabs(
                  tabs: const [
                    GuTabItem(id: 'a', label: 'Hakkında'),
                    GuTabItem(id: 'b', label: 'Etkinlikler'),
                  ],
                  value: 'a',
                  onChanged: (_) {},
                ),
                GuSegmented(
                  options: const [
                    GuSegmentOption(id: 'a', label: 'Yaklaşan'),
                    GuSegmentOption(id: 'b', label: 'Geçmiş'),
                  ],
                  value: 'a',
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
          platform: platform,
        ),
        maxDistance: 1600,
      );
    });
  });
}
