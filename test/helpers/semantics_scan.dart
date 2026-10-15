// Semantik rol doğrulaması · kaydırma taraması.
//
// Flutter 3.44 rol kuralları (`_DebugSemanticsRoleChecks`: `tabBar` boş
// olamaz, çocukları `tab`; `tab` selected + dokunma; `row` → `table` …)
// `flushSemantics` sırasında, yalnızca semantik açıkken çalışır.
// `testWidgets` semantiği varsayılan açık kurar (`semanticsEnabled: true`):
// her ekran testinin durağan kareleri zaten doğrulanır. Kırpmaya bağlı
// ihlaller ise yalnızca belirli kaydırma konumlarında çıkar (ör. önbellek
// kenarı `tabBar` dolgusuna düşünce sekmeler düşer → "a TabBar cannot be
// empty"; iOS simülatörü, erişilebilirlik açık). Bu yardımcı ekranın dikey
// kaydırılabilirlerini ince adımla baştan sona kaydırır ve her karedeki
// istisnayı konumuyla toplar.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Varsayılan adım: 1 px'lik dolgu payını en az iki karede yakalar.
const double kSemanticsScanStep = 0.5;

/// Tarama yapılan platformlar: iOS (44 pt dokunma hedefi → `GuSegmented`
/// dolgu payı açık kalır) ve Android (48 dp).
const List<TargetPlatform> kSemanticsScanPlatforms = [
  TargetPlatform.iOS,
  TargetPlatform.android,
];

/// Her platformda [pump] ile ekranı çizer; ilk karede ve her dikey
/// kaydırılabilirin `[min, min + maxDistance]` aralığında [step] adımla her
/// karede `tester.takeException()`'ın `null` olduğunu doğrular. İhlalde
/// `TestFailure` (platform, kaydırılabilir sırası, konum, ilk satır).
Future<void> expectSemanticsCleanWhileScrolling(
  WidgetTester tester,
  Future<void> Function(TargetPlatform platform) pump, {
  List<TargetPlatform> platforms = kSemanticsScanPlatforms,
  double step = kSemanticsScanStep,
  double maxDistance = 3000,
}) async {
  final handle = tester.ensureSemantics();
  try {
    final failures = <String>[];
    void collect(String where) {
      final error = tester.takeException();
      if (error != null) failures.add('$where: ${'$error'.split('\n').first}');
    }

    for (final platform in platforms) {
      await pump(platform);
      await tester.pump();
      collect('${platform.name} ilk kare');
      final positions = [
        for (final state in tester.stateList<ScrollableState>(
          find.byType(Scrollable),
        ))
          if (axisDirectionToAxis(state.axisDirection) == Axis.vertical)
            state.position,
      ];
      expect(
        positions.any((p) => p.maxScrollExtent > p.minScrollExtent),
        isTrue,
        reason: '${platform.name}: kaydırılabilir içerik yok',
      );
      for (final (index, position) in positions.indexed) {
        final start = position.minScrollExtent;
        for (var offset = start; ; offset += step) {
          // Tembel listelerde kapsam kaydırdıkça büyür: her adımda okunur.
          if (offset >
              math.min(position.maxScrollExtent, start + maxDistance)) {
            break;
          }
          position.jumpTo(offset);
          await tester.pump();
          collect('${platform.name} #$index @${offset.toStringAsFixed(2)}');
        }
        position.jumpTo(start);
        await tester.pump();
      }
    }
    expect(failures, isEmpty);
  } finally {
    handle.dispose();
  }
}
