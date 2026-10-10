// gu_ui widget testleri için uygulama sarmalayıcısı (CD-122(3)).
//
// Kök `test/helpers/pump_app.dart`'ın alt kümesidir: gu_ui kök paketi
// (`package:gu_kulupler`) içe aktaramaz → GetIt, Riverpod ve
// `AppLocalizations` yok; yerel ayar yalnızca Global* Material/Widgets/
// Cupertino delegeleriyle kurulur. `OverflowDetector`/`DeviceMatrix` yalnızca
// köktedir. Varlıklar (`assets/icons` vb.) dosya tabanlı `GuTestAssetBundle`
// ile `DefaultAssetBundle` olarak sağlanır (CD-23, T-03).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import 'test_asset_bundle.dart';

/// `pumpApp` çocuğunu saran `KeyedSubtree` anahtarı (çocuğun bağlamı).
const Key kPumpAppChildKey = ValueKey<String>('pumpApp.child');

/// `MaterialApp`'ı saran `RepaintBoundary` anahtarı (tam ekran görüntü).
const Key kPumpAppBoundaryKey = ValueKey<String>('pumpApp.boundary');

/// Test görünümünün piksel oranı: mantıksal boyut = fiziksel boyut.
const double kPumpAppDevicePixelRatio = 1;

/// Testte desteklenen diller (TR varsayılan, EN).
const List<Locale> kPumpAppLocales = [Locale('tr'), Locale('en')];

extension GuPumpApp on WidgetTester {
  /// [child]'ı `GuTheme.light()/dark()` + TR/EN Global delegeleri +
  /// `MediaQuery` (metin ölçeği, güvenli alan, klavye) + dosya tabanlı
  /// `DefaultAssetBundle` ([GuTestAssetBundle]) içinde çizer.
  ///
  /// Varsayılanlar: TR, açık tema, ölçek 1.0, 390×844, Android. Görünüm
  /// boyutu ve platform test sonunda geri alınır (`tester.view.reset`,
  /// [TestPlatformScope]). Her çağrı ağacı baştan kurar (`UniqueKey`).
  Future<void> pumpApp(
    Widget child, {
    Locale locale = const Locale('tr'),
    ThemeMode theme = ThemeMode.light,
    double textScale = 1.0,
    Size size = const Size(390, 844),
    TargetPlatform platform = TargetPlatform.android,
    EdgeInsets viewPadding = EdgeInsets.zero,
    double keyboardInset = 0,
  }) async {
    view
      ..devicePixelRatio = kPumpAppDevicePixelRatio
      ..physicalSize = size * kPumpAppDevicePixelRatio;
    addTearDown(view.reset);
    TestPlatformScope.apply(platform);

    await pumpWidget(
      TestPlatformScope(
        key: UniqueKey(),
        platform: platform,
        child: DefaultAssetBundle(
          bundle: GuTestAssetBundle.instance,
          child: RepaintBoundary(
            key: kPumpAppBoundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: GuTheme.light().copyWith(platform: platform),
              darkTheme: GuTheme.dark().copyWith(platform: platform),
              themeMode: theme,
              locale: locale,
              supportedLocales: kPumpAppLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
