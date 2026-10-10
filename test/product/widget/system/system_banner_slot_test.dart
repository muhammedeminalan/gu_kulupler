// T-11 · SystemBannerSlot: kök bantların ortak yerleşimi — bant üst güvenli
// alanın altında, içerik bandın altında ve üst güvenli alansız; bant açılıp
// kapanırken içerik yeniden kurulmaz.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/widget/system/system_banner_slot.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/pump_app.dart';

const Key _childKey = ValueKey<String>('slot.child');
const Key _bannerKey = ValueKey<String>('slot.banner');
const Key _innerKey = ValueKey<String>('slot.inner');

/// Bandı aç / kapa yapan sarmalayıcı (aynı ağaç, farklı bant).
final _showBanner = NotifierProvider<_Flag, bool>(_Flag.new);

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool value}) => state = value;
}

/// Kurulum sayısını tutan içerik: yeniden kurulursa sayaç sıfırlanır.
class _Probe extends ConsumerStatefulWidget {
  const _Probe() : super(key: _childKey);

  @override
  ConsumerState<_Probe> createState() => _ProbeState();
}

class _ProbeState extends ConsumerState<_Probe> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => taps++),
    child: const SizedBox.expand(),
  );
}

void main() {
  group('T-11 · SystemBannerSlot', () {
    testWidgets('bant yokken içerik alanı doldurur, güvenli alan içerikte '
        'kalır', (tester) async {
      await tester.pumpApp(
        const SystemBannerSlot(banner: null, child: _Probe()),
        viewPadding: const EdgeInsets.only(top: 47),
      );
      expect(
        tester.getRect(find.byKey(_childKey)),
        Offset.zero & tester.view.physicalSize,
      );
      final media = MediaQuery.of(tester.element(find.byKey(_childKey)));
      expect(media.padding.top, 47);
      expect(media.viewPadding.top, 47);
      expect(find.byType(GuBanner), findsNothing);
    });

    testWidgets('bant üst güvenli alanın altında başlar; içerik bandın '
        'altından başlar ve üst güvenli alanı yeniden eklemez', (tester) async {
      await tester.pumpApp(
        const SystemBannerSlot(
          banner: GuBanner(key: _bannerKey, text: 'x'),
          child: _Probe(),
        ),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );
      final banner = tester.getRect(find.byKey(_bannerKey));
      expect(banner.top, 47);
      expect(banner.left, 0);
      expect(banner.width, 390);
      expect(tester.getRect(find.byKey(_childKey)).top, banner.bottom);
      expect(tester.getRect(find.byKey(_childKey)).bottom, 844);
      final media = MediaQuery.of(tester.element(find.byKey(_childKey)));
      expect(media.padding.top, 0);
      expect(media.viewPadding.top, 0);
      // Alt güvenli alan dokunulmadan içeriğe geçer.
      expect(media.viewPadding.bottom, 34);
    });

    testWidgets('bant açılıp kapanırken içerik yeniden kurulmaz', (
      tester,
    ) async {
      await tester.pumpApp(
        Consumer(
          builder: (context, ref, _) => SystemBannerSlot(
            banner: ref.watch(_showBanner)
                ? const GuBanner(key: _bannerKey, text: 'x')
                : null,
            child: const _Probe(),
          ),
        ),
      );
      await tester.tap(find.byKey(_childKey));
      final state = tester.state<_ProbeState>(find.byKey(_childKey));
      expect(state.taps, 1);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(_childKey)),
      );
      container.read(_showBanner.notifier).set(value: true);
      await tester.pump();
      expect(find.byKey(_bannerKey), findsOneWidget);
      expect(tester.state<_ProbeState>(find.byKey(_childKey)), same(state));

      container.read(_showBanner.notifier).set(value: false);
      await tester.pump();
      expect(find.byKey(_bannerKey), findsNothing);
      expect(tester.state<_ProbeState>(find.byKey(_childKey)), same(state));
      expect(state.taps, 1);
    });

    testWidgets('iç içe: dıştaki bant güvenli alanı tüketir, içteki ek boşluk '
        'bırakmaz', (tester) async {
      await tester.pumpApp(
        const SystemBannerSlot(
          banner: GuBanner(key: _bannerKey, text: 'dış'),
          child: SystemBannerSlot(
            banner: GuBanner(key: _innerKey, text: 'iç'),
            child: _Probe(),
          ),
        ),
        viewPadding: const EdgeInsets.only(top: 59),
      );
      final outer = tester.getRect(find.byKey(_bannerKey));
      final inner = tester.getRect(find.byKey(_innerKey));
      expect(outer.top, 59);
      expect(inner.top, outer.bottom);
      expect(tester.getRect(find.byKey(_childKey)).top, inner.bottom);
    });
  });
}
