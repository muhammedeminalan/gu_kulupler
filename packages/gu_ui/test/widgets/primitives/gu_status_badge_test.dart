// T-04 · GuStatusBadge (widget-catalog #15; CD-27 sarmalayıcı).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/widgets/primitives/gu_badge.dart';
import 'package:gu_ui/src/widgets/primitives/gu_status_badge.dart';

import '../../helpers/design_sources.dart';
import '../../helpers/pump_app.dart';

/// Dart üye adı → kayıt anahtarı (`void` ayrılmış sözcük → `voided`).
String _registryKey(GuStatusBadgeKind kind) =>
    kind == GuStatusBadgeKind.voided ? 'void' : kind.name;

void main() {
  group('T-04 · GuStatusBadge', () {
    testWidgets('T-04 · GuStatusBadge · registry.json#statusBadge tablosu '
        '(21 durum: sınıf + ikon, void → voided) ve GuBadge sarmalı', (
      tester,
    ) async {
      final table = registry()['statusBadge'] as Map<String, dynamic>;
      expect(GuStatusBadgeKind.values, hasLength(21));
      expect(
        GuStatusBadgeKind.values.map(_registryKey),
        orderedEquals(table.keys),
      );
      for (final kind in GuStatusBadgeKind.values) {
        final [cssClass, iconName] =
            (table[_registryKey(kind)] as List<dynamic>).cast<String>();
        expect('badge-${kind.badgeKind.name}', cssClass, reason: kind.name);
        expect(kind.icon.fileName, iconName, reason: kind.name);

        await tester.pumpApp(
          Center(
            child: GuStatusBadge(kind: kind, label: 'Durum ${kind.name}'),
          ),
        );
        final badge = tester.widget<GuBadge>(find.byType(GuBadge));
        expect(badge.kind, kind.badgeKind);
        expect(badge.icon, kind.icon);
        expect(badge.label, 'Durum ${kind.name}');
        expect(
          tester.getSize(find.byType(GuStatusBadge)),
          tester.getSize(find.byType(GuBadge)),
        );
      }
    });

    testWidgets('T-04 · GuStatusBadge · 320 dp × 1.6 uzun durum metni taşmaz; '
        'Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final long = 'Bekleme listesinde sıra bekliyor ' * 6;
      await tester.pumpApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GuStatusBadge(
                kind: GuStatusBadgeKind.attended,
                label: 'Katıldın',
              ),
              GuStatusBadge(kind: GuStatusBadgeKind.waitlist, label: long),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(GuStatusBadge).last),
        const Size(320, 22),
      );
      expect(find.bySemanticsLabel('Katıldın'), findsOneWidget);
      handle.dispose();
    });
  });
}
