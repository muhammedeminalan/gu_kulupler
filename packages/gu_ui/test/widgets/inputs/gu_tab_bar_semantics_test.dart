// T-05 · GuTabs / GuSegmented · semantik rol sözleşmesi (Flutter 3.44
// `_DebugSemanticsRoleChecks`): `tabBar` boş olamaz ve çocukları yalnızca
// `tab` rollüdür; `tab` `selected` durumu + dokunma eylemi ister (eylemler
// engelli ya da düğüm devre dışı değilse). Doğrulama yalnızca semantik
// açıkken ve `flushSemantics` sırasında çalışır (`testWidgets` varsayılanı
// `semanticsEnabled: true`; ihlal `tester.takeException()`'a düşer).
//
// Regresyon: `tabBar` düğümü dolguyu (GuTabs alt 1 px, GuSegmented 3 px)
// kapsadığında kaydırma görünümünün semantik kırpması (önbellek kenarı) o
// payın içine düşen karede sekme düğümleri boş dikdörtgenle düşüyor, çubuk
// çocuksuz kalıyordu ("a TabBar cannot be empty", iOS simülatörü,
// erişilebilirlik açık).
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const List<GuTabItem> _tabs = [
  GuTabItem(id: 'about', label: 'Hakkında'),
  GuTabItem(id: 'events', label: 'Etkinlikler'),
  GuTabItem(id: 'posts', label: 'Gönderiler', count: 3),
];

const List<GuTabItem> _longTabs = [
  GuTabItem(id: 'active', label: 'Active memberships'),
  GuTabItem(id: 'pending', label: 'Pending applications', count: 12),
  GuTabItem(id: 'history', label: 'Membership history', icon: GuIcons.history),
];

const List<GuSegmentOption> _options = [
  GuSegmentOption(id: 'list', label: 'Liste', icon: GuIcons.list),
  GuSegmentOption(id: 'calendar', label: 'Takvim', icon: GuIcons.calendarDays),
];

const List<GuSegmentOption> _fourOptions = [
  GuSegmentOption(id: 'a', label: 'Yaklaşan etkinlikler'),
  GuSegmentOption(id: 'b', label: 'Geçmiş etkinlikler'),
  GuSegmentOption(id: 'c', label: 'Taslaklar'),
  GuSegmentOption(id: 'd', label: 'İptal edilenler'),
];

const List<TargetPlatform> _platforms = [
  TargetPlatform.android,
  TargetPlatform.iOS,
];

/// Senaryo: ad, widget, beklenen `tabBar` sayısı, eylemler engelli mi.
typedef _Scenario = ({
  String name,
  Widget child,
  int bars,
  bool blocked,
  Size size,
  double textScale,
});

_Scenario _scenario(
  String name,
  Widget child, {
  int bars = 1,
  bool blocked = false,
  Size size = const Size(390, 844),
  double textScale = 1,
}) => (
  name: name,
  child: child,
  bars: bars,
  blocked: blocked,
  size: size,
  textScale: textScale,
);

GuTabs _guTabs(List<GuTabItem> tabs, String value) =>
    GuTabs(tabs: tabs, value: value, onChanged: (_) {});

GuSegmented _guSegmented(List<GuSegmentOption> options, String value) =>
    GuSegmented(options: options, value: value, onChanged: (_) {});

List<_Scenario> get _scenarios => [
  _scenario('GuTabs · normal', _guTabs(_tabs, 'about')),
  _scenario('GuTabs · tek sekme', _guTabs(_tabs.take(1).toList(), 'about')),
  _scenario('GuTabs · seçimsiz değer', _guTabs(_tabs, 'none')),
  _scenario(
    'GuTabs · kaydırılabilir, seçili sekme ekran dışından gelir',
    _guTabs(_longTabs, 'history'),
    size: const Size(320, 640),
    textScale: 1.6,
  ),
  _scenario(
    'GuTabs · etkileşimsiz (IgnorePointer + Opacity)',
    IgnorePointer(
      child: Opacity(
        opacity: GuOpacity.disabled,
        child: _guTabs(_tabs, 'events'),
      ),
    ),
    blocked: true,
  ),
  _scenario('GuTabs · boş liste', _guTabs(const [], 'about'), bars: 0),
  _scenario('GuSegmented · normal', _guSegmented(_options, 'list')),
  _scenario(
    'GuSegmented · tek seçenek',
    _guSegmented(_options.take(1).toList(), 'list'),
  ),
  _scenario('GuSegmented · seçimsiz değer', _guSegmented(_options, 'none')),
  _scenario(
    'GuSegmented · 4 seçenek, 320 × 1.6 (üç nokta)',
    _guSegmented(_fourOptions, 'd'),
    size: const Size(320, 640),
    textScale: 1.6,
  ),
  _scenario(
    'GuSegmented · etkileşimsiz (IgnorePointer + Opacity, FED-03 düzenleme)',
    IgnorePointer(
      child: Opacity(
        opacity: GuOpacity.disabled,
        child: _guSegmented(_options, 'calendar'),
      ),
    ),
    blocked: true,
  ),
  _scenario(
    'GuSegmented · boş liste',
    _guSegmented(const [], 'list'),
    bars: 0,
  ),
];

/// Semantik ağacının kökü (tek görünüm).
SemanticsNode _root(WidgetTester tester) =>
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!;

List<SemanticsNode> _children(SemanticsNode node) {
  final result = <SemanticsNode>[];
  node.visitChildren((child) {
    result.add(child);
    return true;
  });
  return result;
}

List<SemanticsNode> _nodesWithRole(WidgetTester tester, SemanticsRole role) {
  final result = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().role == role) result.add(node);
    _children(node).forEach(visit);
  }

  visit(_root(tester));
  return result;
}

/// Her `tabBar` en az bir çocuklu; çocukların hepsi `tab` + `selected`
/// durumu + etiket + (engelli değilse) dokunma eylemi.
void _expectTabBarContract(
  WidgetTester tester, {
  required int bars,
  required bool blocked,
  required String reason,
}) {
  final found = _nodesWithRole(tester, SemanticsRole.tabBar);
  expect(found, hasLength(bars), reason: reason);
  for (final bar in found) {
    final tabs = _children(bar);
    expect(tabs, isNotEmpty, reason: reason);
    for (final tab in tabs) {
      expect(tab.getSemanticsData().role, SemanticsRole.tab, reason: reason);
      expect(
        tab,
        isSemantics(
          hasSelectedState: true,
          isButton: true,
          hasTapAction: !blocked,
        ),
        reason: reason,
      );
      expect(tab.getSemanticsData().label, isNotEmpty, reason: reason);
    }
  }
}

void main() {
  group('T-05 · GuTabs / GuSegmented · semantik rol sözleşmesi', () {
    testWidgets('her durumda istisna yok; tabBar → yalnızca tab çocukları '
        '(selected + dokunma + etiket); boş listede tabBar rolü yok', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final platform in _platforms) {
        for (final s in _scenarios) {
          final reason = '${s.name} · ${platform.name}';
          await tester.pumpApp(
            Align(alignment: Alignment.topCenter, child: s.child),
            platform: platform,
            size: s.size,
            textScale: s.textScale,
          );
          // Kaydırılabilir kipte seçili sekme sonraki karede görünür alana
          // kayar (`ensureVisible`).
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: reason);
          _expectTabBarContract(
            tester,
            bars: s.bars,
            blocked: s.blocked,
            reason: reason,
          );
        }
      }
      handle.dispose();
    });

    testWidgets('seçili düğüm tek; ekran dışı sekme düşmez (gizli kalır), '
        'yatay kaydırmada istisna yok', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        Align(
          alignment: Alignment.topCenter,
          child: _guTabs(_longTabs, 'active'),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      final bar = _nodesWithRole(tester, SemanticsRole.tabBar).single;
      final tabs = _children(bar);
      expect(tabs, hasLength(3));
      expect(
        tabs.where(
          (tab) =>
              tab.getSemanticsData().flagsCollection.isSelected ==
              Tristate.isTrue,
        ),
        hasLength(1),
      );
      for (var step = 0; step < 40; step++) {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(-13.7, 0),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'adım $step');
      }
      expect(
        _children(_nodesWithRole(tester, SemanticsRole.tabBar).single),
        hasLength(3),
      );
      handle.dispose();
    });

    testWidgets('dikey listede önbellek kenarı çubuğun içinden geçerken '
        '(0.125 px adım) hiçbir karede "a TabBar cannot be empty" yok', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      // `pumpApp` varsayılan görünümü.
      const viewport = Size(390, 844);
      const tabsTop = 1200.0;
      const gap = 150.0;
      for (final platform in _platforms) {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpApp(
          ListView(
            controller: controller,
            children: [
              const SizedBox(height: tabsTop),
              _guTabs(_tabs, 'about'),
              const SizedBox(height: gap),
              _guSegmented(_options, 'list'),
              const SizedBox(height: 2000),
            ],
          ),
          platform: platform,
        );
        // Henüz kurulmamış (önbellek dışı) widget ölçülemez: token ölçüleri.
        const segmentedBottom =
            tabsTop +
            GuSizes.tabHeight +
            GuSizes.tabBorder +
            gap +
            GuSizes.segmentHeight +
            GuSizes.segmentPadding * 2;
        const cache = RenderAbstractViewport.defaultCacheExtent;
        // Alt kenar (görünüm + önbellek) ve üst kenar (− önbellek) iki
        // widget'ın içinden geçecek biçimde kaydırma pencereleri (+ pay).
        const margin = 8.0;
        final windows = [
          (
            tabsTop - viewport.height - cache - margin,
            segmentedBottom - viewport.height - cache + margin,
          ),
          (tabsTop + cache - margin, segmentedBottom + cache + margin),
        ];
        final failures = <String>[];
        for (final (start, end) in windows) {
          for (var offset = start; offset <= end; offset += 0.125) {
            controller.jumpTo(offset);
            await tester.pump();
            final error = tester.takeException();
            if (error != null) {
              failures.add(
                '${offset.toStringAsFixed(3)}: ${'$error'.split('\n').first}',
              );
            }
          }
        }
        expect(failures, isEmpty, reason: platform.name);
      }
      handle.dispose();
    });

    testWidgets('GuActionSurface(role) · rol düğme düğümünde; semanticLabel '
        'çocukları dışlasa da korunur; devre dışı sekme dokunmasız geçerli', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Widget surface({
        required Key key,
        required bool selected,
        String? label,
        bool enabled = true,
      }) => GuActionSurface(
        key: key,
        onTap: () {},
        enabled: enabled,
        selected: selected,
        role: SemanticsRole.tab,
        semanticLabel: label,
        borderRadius: GuRadius.borderChip,
        builder: (context, _) => const SizedBox(
          width: 120,
          height: 48,
          child: Center(child: Text('Görünen')),
        ),
      );
      const labelled = ValueKey<String>('labelled');
      const plain = ValueKey<String>('plain');
      const disabled = ValueKey<String>('disabled');
      await tester.pumpApp(
        Align(
          alignment: Alignment.topCenter,
          child: Semantics(
            role: SemanticsRole.tabBar,
            container: true,
            explicitChildNodes: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                surface(key: labelled, selected: true, label: 'Etiket'),
                surface(key: plain, selected: false),
                surface(key: disabled, selected: false, enabled: false),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final first = tester.getSemantics(find.byKey(labelled));
      expect(first.getSemanticsData().role, SemanticsRole.tab);
      expect(
        first,
        isSemantics(
          label: 'Etiket',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(plain)),
        isSemantics(label: 'Görünen', hasSelectedState: true),
      );
      final off = tester.getSemantics(find.byKey(disabled));
      expect(off.getSemanticsData().role, SemanticsRole.tab);
      expect(
        off,
        isSemantics(
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      expect(first.parent!.getSemanticsData().role, SemanticsRole.tabBar);
      handle.dispose();
    });
  });
}
