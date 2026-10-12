// T-11 · GuApp ilk kurulum: `runApp` ağacı kare DIŞINDA (zamanlayıcı evresi
// `idle`) kurar; router ilk konumunu o kurulum sırasında bildirir. Konum
// dinleyicisi o anda üst katmanı yeniden kurmaya çalışmamalıdır
// ("setState() or markNeedsBuild() called during build").
//
// Test ortamında kök öğe hazır olduğundan `pumpWidget` ağacı kare içinde
// kurar; üretimdeki yolu taklit etmek için GuApp, kare dışında eşzamanlı
// `buildScope` ile kurulur.
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/register_fakes.dart';

class _Host extends StatefulWidget {
  const _Host({required this.child});

  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool show = false;

  void reveal() => setState(() => show = true);

  @override
  Widget build(BuildContext context) =>
      show ? widget.child : const SizedBox.shrink();
}

void main() {
  testWidgets('T-11 · GuApp · kare dışı ilk kurulumda router bildirimi '
      'yeniden kurulum hatası üretmez', (tester) async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
            .values[AppPreferenceKeys.notificationPermissionAsked] =
        true;
    final controller = GuToastController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.active,
          ),
        ],
        child: _Host(child: GuApp(toastController: controller)),
      ),
    );
    expect(find.byType(GuApp), findsNothing);

    // `runApp` yolu: ağaç bir kare beklemeden, olduğu yerde kurulur.
    expect(SchedulerBinding.instance.schedulerPhase, SchedulerPhase.idle);
    tester.state<_HostState>(find.byType(_Host)).reveal();
    tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);

    expect(find.byType(GuApp), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
