// T-04 · GuRoleBadge (widget-catalog #14; CD-27 sarmalayıcı).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/widgets/primitives/gu_badge.dart';
import 'package:gu_ui/src/widgets/primitives/gu_role_badge.dart';

import '../../helpers/design_sources.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('T-04 · GuRoleBadge', () {
    testWidgets('T-04 · GuRoleBadge · registry.json#roleBadge tablosu (5 rol: '
        'sınıf + ikon) ve GuBadge sarmalı', (tester) async {
      final table = registry()['roleBadge'] as Map<String, dynamic>;
      expect(
        GuRoleBadgeKind.values.map((kind) => kind.name),
        orderedEquals(table.keys),
      );
      expect(GuRoleBadgeKind.values, hasLength(5));
      for (final kind in GuRoleBadgeKind.values) {
        final [cssClass, iconName] = (table[kind.name] as List<dynamic>)
            .cast<String>();
        expect('badge-${kind.badgeKind.name}', cssClass, reason: kind.name);
        expect(kind.icon.fileName, iconName, reason: kind.name);

        await tester.pumpApp(
          Center(
            child: GuRoleBadge(kind: kind, label: 'Rol ${kind.name}'),
          ),
        );
        // Kendi gövdesi yok: tek GuBadge, türün rengi ve ikonu ile.
        final badge = tester.widget<GuBadge>(find.byType(GuBadge));
        expect(badge.kind, kind.badgeKind);
        expect(badge.icon, kind.icon);
        expect(badge.label, 'Rol ${kind.name}');
        expect(
          tester.getSize(find.byType(GuRoleBadge)),
          tester.getSize(find.byType(GuBadge)),
        );
      }
    });

    testWidgets('T-04 · GuRoleBadge · 320 dp × 1.6 uzun rol adı taşmaz; '
        'Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final long = 'Yönetim Kurulu Üyesi ' * 8;
      await tester.pumpApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GuRoleBadge(
                kind: GuRoleBadgeKind.president,
                label: 'Başkan',
              ),
              GuRoleBadge(kind: GuRoleBadgeKind.board, label: long),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
        theme: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(GuRoleBadge).last),
        const Size(320, 22),
      );
      expect(find.bySemanticsLabel('Başkan'), findsOneWidget);
      handle.dispose();
    });
  });
}
