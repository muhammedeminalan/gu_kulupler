// Kök test sarmalayıcısı (PLAN §16.2, testing.md §2).
//
// `route:` / `wrapInShell:` T-11'de (router + `AppShellView`) eklenir.
// `GuSkeleton.debugAnimate` test boyunca `false`'tur (CD-122(2)).
// gu_ui'nin alt küme kopyası: `packages/gu_ui/test/helpers/pump_app.dart`
// (paket sınırı, CD-122(3)).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';
// T-06: `GuSkeleton` barrel'a eklenince bu satır kalkar (gu_ui.dart yeter).

import '../fakes/register_fakes.dart';

/// `pumpApp` çocuğunu saran `KeyedSubtree` anahtarı: çocuğun bağlamı
/// (`tester.l10n`, `test_l10n.dart`). `GuKey.pattern`'e uymaz → aksiyon
/// envanterine girmez.
const Key kPumpAppChildKey = ValueKey<String>('pumpApp.child');

/// `MaterialApp`'ı saran `RepaintBoundary` anahtarı (tam ekran golden;
/// sheet/dialog/toast katmanları dahil).
const Key kPumpAppBoundaryKey = ValueKey<String>('pumpApp.boundary');

/// Test görünümünün piksel oranı: mantıksal boyut = fiziksel boyut.
const double kPumpAppDevicePixelRatio = 1;

extension PumpApp on WidgetTester {
  /// [child]'ı uygulama bağlamında çizer: `GetIt.I.reset()` +
  /// `registerDefaultFakes()`, `ProviderScope(overrides)`,
  /// `GuTheme.light()/dark()`, `AppLocalizations` + Global delegeler,
  /// `MediaQuery` (metin ölçeği, güvenli alan, klavye), platform.
  ///
  /// Varsayılanlar: TR, açık tema, ölçek 1.0, 390×844, Android. Görünüm
  /// boyutu, platform ve GetIt test sonunda geri alınır. Her çağrı ağacı
  /// (ve `ProviderContainer`'ı) baştan kurar (`UniqueKey`). `OverflowDetector`
  /// burada kurulmaz (`DeviceMatrix.run` kurar).
  Future<void> pumpApp(
    Widget child, {
    Locale locale = const Locale('tr'),
    ThemeMode theme = ThemeMode.light,
    double textScale = 1.0,
    Size size = const Size(390, 844),
    TargetPlatform platform = TargetPlatform.android,
    List<Override> overrides = const [],
    EdgeInsets viewPadding = EdgeInsets.zero,
    double keyboardInset = 0,
  }) async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);

    view
      ..devicePixelRatio = kPumpAppDevicePixelRatio
      ..physicalSize = size * kPumpAppDevicePixelRatio;
    addTearDown(view.reset);
    TestPlatformScope.apply(platform);
    // Sonsuz shimmer `pumpAndSettle`'ı kilitler, golden'ı kararsız yapar
    // (CD-122(2)).
    GuSkeleton.debugAnimate = false;
    addTearDown(() => GuSkeleton.debugAnimate = true);

    await pumpWidget(
      TestPlatformScope(
        key: UniqueKey(),
        platform: platform,
        child: ProviderScope(
          overrides: overrides,
          child: RepaintBoundary(
            key: kPumpAppBoundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: GuTheme.light().copyWith(platform: platform),
              darkTheme: GuTheme.dark().copyWith(platform: platform),
              themeMode: theme,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, navigator) => MediaQuery(
                data: testMediaQuery(
                  MediaQuery.of(context),
                  textScale: textScale,
                  viewPadding: viewPadding,
                  keyboardInset: keyboardInset,
                ),
                child: navigator!,
              ),
              home: KeyedSubtree(key: kPumpAppChildKey, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// [base] üzerine test `MediaQuery` alanları: `textScaler`, `viewPadding`,
/// klavye `viewInsets.bottom` ve ondan türeyen `padding`
/// (`padding = viewPadding − viewInsets`, alt kenar ≥ 0).
MediaQueryData testMediaQuery(
  MediaQueryData base, {
  required double textScale,
  required EdgeInsets viewPadding,
  required double keyboardInset,
}) => base.copyWith(
  textScaler: TextScaler.linear(textScale),
  viewPadding: viewPadding,
  viewInsets: EdgeInsets.only(bottom: keyboardInset),
  padding: viewPadding.copyWith(
    bottom: math.max(0, viewPadding.bottom - keyboardInset),
  ),
);

/// `debugDefaultTargetPlatformOverride`'ı ağaç ömrüne bağlar.
///
/// flutter_test, foundation hata ayıklama değişkenlerini test gövdesi biter
/// bitmez (`addTearDown`'dan önce) denetler; değişken o anda `null`
/// değilse test düşer. Test sonunda ağaç sökülürken bu widget'ın
/// `dispose`'u değişkeni sıfırlar. Art arda `pumpApp` çağrılarında
/// sahiplik son kurulan kapsama geçer (eski kapsamın `dispose`'u
/// dokunmaz). Test hata ile biterse (ağaç sökülmez) `apply`'ın kaydettiği
/// `addTearDown` sıfırlar.
class TestPlatformScope extends StatefulWidget {
  const TestPlatformScope({
    required this.platform,
    required this.child,
    super.key,
  });

  final TargetPlatform platform;
  final Widget child;

  static Object? _owner;

  /// Değişkeni hemen [platform]'a çeker (tema bu çağrıdan sonra kurulur) ve
  /// test sonu için güvence sıfırlamasını kaydeder.
  static void apply(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      _owner = null;
    });
  }

  @override
  State<TestPlatformScope> createState() => _TestPlatformScopeState();
}

class _TestPlatformScopeState extends State<TestPlatformScope> {
  @override
  void initState() {
    super.initState();
    TestPlatformScope._owner = this;
    debugDefaultTargetPlatformOverride = widget.platform;
  }

  @override
  void didUpdateWidget(TestPlatformScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    TestPlatformScope._owner = this;
    debugDefaultTargetPlatformOverride = widget.platform;
  }

  @override
  void dispose() {
    if (identical(TestPlatformScope._owner, this)) {
      TestPlatformScope._owner = null;
      debugDefaultTargetPlatformOverride = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
