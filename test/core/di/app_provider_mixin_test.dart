// T-11 · AppProviderMixin / AppProviderStateMixin: view'ların kök
// ViewModel'lere tek biçimli erişimi (D-04, CD-92).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_view_model.dart';
import 'package:gu_kulupler/core/di/app_provider_mixin.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_session_states.dart';
import '../../helpers/pump_app.dart';

int _statefulBuilds = 0;
int _statelessBuilds = 0;

class _StatefulProbe extends ConsumerStatefulWidget {
  const _StatefulProbe();

  @override
  ConsumerState<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends ConsumerState<_StatefulProbe>
    with AppProviderMixin<_StatefulProbe> {
  @override
  Widget build(BuildContext context) {
    _statefulBuilds++;
    return Column(
      children: [
        Text('offline:$isOffline'),
        Text('scale:${appPreferences.textScale.name}'),
        TextButton(
          onPressed: () =>
              appPreferencesNotifier.setTextScale(GuTextScaleLevel.s130),
          child: const Text('set'),
        ),
      ],
    );
  }
}

class _StatelessProbe extends ConsumerWidget with AppProviderStateMixin {
  const _StatelessProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _statelessBuilds++;
    return Column(
      children: [
        Text('offline:${isOfflineOf(ref)}'),
        Text('theme:${appPreferencesOf(ref).themeMode.name}'),
      ],
    );
  }
}

class _SessionProbe extends ConsumerStatefulWidget {
  const _SessionProbe();

  @override
  ConsumerState<_SessionProbe> createState() => _SessionProbeState();
}

class _SessionProbeState extends ConsumerState<_SessionProbe>
    with AppProviderMixin<_SessionProbe> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('status:${session.status.name}'),
      Text('uid:$uid'),
      Text('super:$isSuperAdmin'),
      TextButton(
        onPressed: () => sessionNotifier.onTokenExpired(),
        child: const Text('expire'),
      ),
    ],
  );
}

class _SessionStatelessProbe extends ConsumerWidget with AppProviderStateMixin {
  const _SessionStatelessProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text('status:${sessionOf(ref).status.name}');
}

void main() {
  setUp(() {
    _statefulBuilds = 0;
    _statelessBuilds = 0;
  });

  group('T-11 · AppProviderMixin (ConsumerState)', () {
    testWidgets('tercihleri ve çevrimdışı durumunu okur; yazıcıya erişir', (
      tester,
    ) async {
      await tester.pumpApp(const _StatefulProbe());
      expect(find.text('offline:false'), findsOneWidget);
      expect(find.text('scale:s100'), findsOneWidget);

      await tester.tap(find.text('set'));
      await tester.pump();
      expect(find.text('scale:s130'), findsOneWidget);
    });

    testWidgets('çevrimdışı olunca yeniden kurar', (tester) async {
      await tester.pumpApp(const _StatefulProbe());
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).emit(true);
      await tester.pump();
      await tester.pump();
      expect(find.text('offline:true'), findsOneWidget);
    });

    testWidgets('isOffline select ile izlenir: başka alan değişince yeniden '
        'kurmaz', (tester) async {
      await tester.pumpApp(const _StatefulProbe());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_StatefulProbe)),
      );
      final before = _statefulBuilds;

      container.read(connectivityViewModelProvider.notifier).setFromCache(true);
      await tester.pump();
      expect(_statefulBuilds, before);
    });
  });

  group('T-11 · AppProviderStateMixin (ConsumerWidget)', () {
    testWidgets('tercihleri ve çevrimdışı durumunu okur', (tester) async {
      await tester.pumpApp(const _StatelessProbe());
      expect(find.text('offline:false'), findsOneWidget);
      expect(find.text('theme:system'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(_StatelessProbe)),
      );
      await container
          .read(appPreferencesViewModelProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pump();
      expect(find.text('theme:dark'), findsOneWidget);
    });

    testWidgets('isOfflineOf select ile izlenir', (tester) async {
      await tester.pumpApp(const _StatelessProbe());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_StatelessProbe)),
      );
      final before = _statelessBuilds;
      container.read(connectivityViewModelProvider.notifier).setFromCache(true);
      await tester.pump();
      expect(_statelessBuilds, before);

      (GetIt.I<ConnectivityService>() as FakeConnectivityService).emit(true);
      await tester.pump();
      await tester.pump();
      expect(find.text('offline:true'), findsOneWidget);
      expect(_statelessBuilds, greaterThan(before));
    });
  });

  group('T-11 · AppProviderMixin · oturum (CD-92)', () {
    testWidgets('session / uid / isSuperAdmin okunur; değişince yeniden '
        'kurar', (tester) async {
      await tester.pumpApp(
        const _SessionProbe(),
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.active,
          ),
        ],
      );
      expect(find.text('status:active'), findsOneWidget);
      expect(find.text('uid:${FakeSessionStates.uid}'), findsOneWidget);
      expect(find.text('super:false'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(_SessionProbe)),
      );
      container.read(sessionViewModelProvider.notifier).state =
          FakeSessionStates.activeSuper;
      await tester.pump();
      expect(find.text('super:true'), findsOneWidget);
    });

    testWidgets('sessionNotifier oturum işlemlerine erişir', (tester) async {
      await tester.pumpApp(
        const _SessionProbe(),
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.active,
          ),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_SessionProbe)),
      );
      expect(container.read(sessionViewModelProvider).sessionExpired, isFalse);
      await tester.tap(find.text('expire'));
      await tester.pump();
      expect(container.read(sessionViewModelProvider).sessionExpired, isTrue);
    });

    testWidgets('varsayılan fake ile oturum yok → signedOut', (tester) async {
      await tester.pumpApp(const _SessionProbe());
      await tester.pump();
      expect(find.text('status:${AuthStatus.signedOut.name}'), findsOneWidget);
      expect(find.text('uid:null'), findsOneWidget);
    });

    testWidgets('AppProviderStateMixin.sessionOf (ConsumerWidget)', (
      tester,
    ) async {
      await tester.pumpApp(
        const _SessionStatelessProbe(),
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.unverified,
          ),
        ],
      );
      expect(find.text('status:unverified'), findsOneWidget);
    });
  });
}
