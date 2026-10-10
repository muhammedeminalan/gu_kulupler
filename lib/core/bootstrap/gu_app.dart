import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/features/system/debug_menu/view/widget/debug_menu_corner_button.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/widget/system/app_gate.dart';
import 'package:gu_kulupler/product/widget/system/maintenance_banner.dart';
import 'package:gu_kulupler/product/widget/system/offline_banner.dart';
import 'package:gu_ui/gu_ui.dart';

/// Uygulama kökü (architecture §3; PLAN §4.4, §15.11): `MaterialApp.router`
/// + kök katman zinciri.
///
/// Tema, dil ve metin ölçeği `AppPreferencesViewModel`'den okunur; rota ağacı
/// `appRouterProvider`'dandır. `builder` zinciri — **en dıştan içe, tek sıra**
/// (`gu_app_test.dart` doğrular):
///
/// 1. `GuTextScale` — uygulama × sistem metin ölçeği, tavan 1.6 (Q-14)
/// 2. `GuSystemUi` — durum / gezinme çubuğu stili (D-20); hemen altında kök
///    metin stili (`DefaultTextStyle`, `.gu-root`)
/// 3. `GuToastHost` — toast katmanı; alt çubuk görünürken onun üstünde
/// 4. `GuContentColumn` — geniş ekranda 480 dp ortalı sütun (Q-13, CD-29)
/// 5. `OfflineBanner` — çevrimdışı bandı (SYS-03; yalnızca uygulama
///    kabuğunda)
/// 6. `MaintenanceBanner` — bakım mesajı bandı (CD-48)
/// 7. `AppGate` — zorunlu güncelleme (DLG-26) → oturum sona erdi (DLG-27)
/// 8. `DebugMenuCornerButton` — yalnızca `AppEnvironment.debugMenuEnabled`
///    (CD-69)
///
/// Build hatası yer tutucusu (`ErrorWidget.builder`) açılışta
/// `AppErrorHandler.install` ile kurulur; zincirde widget'ı yoktur.
class GuApp extends ConsumerStatefulWidget {
  /// [toastController]: `FeedbackService` ile paylaşılan toast kuyruğu
  /// (`AppBootstrap.run` verir).
  const GuApp({required this.toastController, super.key});

  /// `GuToastHost`'un denetleyicisi.
  final GuToastController toastController;

  /// Cihaz dili → uygulama dili (PLAN §14.10): `en*` → İngilizce, diğer her
  /// şey → Türkçe (varsayılan).
  static Locale resolveLocale(Locale? device, Iterable<Locale> supported) {
    for (final locale in supported) {
      if (locale.languageCode == device?.languageCode) return locale;
    }
    return fallbackLocale;
  }

  /// Desteklenmeyen cihaz dilinde kullanılan dil.
  static const Locale fallbackLocale = Locale('tr');

  @override
  ConsumerState<GuApp> createState() => _GuAppState();
}

class _GuAppState extends ConsumerState<GuApp> {
  /// Gövdenin (gezgin) ağaçtaki kimliği: 480 dp eşiği aşılınca
  /// `GuContentColumn` araya girer; gövde yeniden kurulmaz, taşınır.
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'gu-app-body');

  /// Router'ın geçerli konumu (bant ve toast yerleşimi buna bağlıdır).
  final ValueNotifier<Uri> _location = ValueNotifier<Uri>(Uri());

  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _attach(ref.read(appRouterProvider));
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _location.dispose();
    super.dispose();
  }

  void _attach(GoRouter router) {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    router.routerDelegate.addListener(_onRouteChanged);
    _location.value = router.routerDelegate.currentConfiguration.uri;
  }

  void _onRouteChanged() {
    // Router ilk konumunu kendi kurulumu sırasında bildirir; üst katman o
    // karede yeniden kurulamaz — konum karenin ardından okunur.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _readLocation());
      return;
    }
    _readLocation();
  }

  void _readLocation() {
    final router = _router;
    if (!mounted || router == null) return;
    _location.value = router.routerDelegate.currentConfiguration.uri;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appRouterProvider, (_, next) => _attach(next));
    final preferences = ref.watch(appPreferencesViewModelProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: GuTheme.light(),
      darkTheme: GuTheme.dark(),
      themeMode: preferences.themeMode,
      locale: preferences.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: GuApp.resolveLocale,
      routerConfig: router,
      builder: (context, child) => GuTextScale(
        level: preferences.textScale,
        child: GuSystemUi(
          // Kök metin stili (`.gu-root`, css:77): gezginin üstündeki bantlar
          // ve kök gezgine itilen sheet / dialog / menü bir `Scaffold`
          // altında değildir; stil buradan gelmezse Flutter'ın "Material
          // yok" uyarı stili (sarı alt çizgi) görünür.
          child: DefaultTextStyle(
            style: context.gu.text.bodyM,
            child: ValueListenableBuilder<Uri>(
              valueListenable: _location,
              builder: (context, location, _) => _layers(
                context,
                router,
                location,
                KeyedSubtree(
                  key: _bodyKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Zincirin konuma bağlı katmanları (3–8).
  Widget _layers(
    BuildContext context,
    GoRouter router,
    Uri location,
    Widget body,
  ) {
    var content = body;
    if (AppEnvironment.debugMenuEnabled) {
      content = DebugMenuCornerButton(
        onPressed: () => router.go(AppPaths.debug),
        child: content,
      );
    }
    return GuToastHost(
      controller: widget.toastController,
      // Sekme kökünde toast alt çubuğun üstünde durur (`.above-nav`).
      bottomInset: GuTab.isTabRoot(location) ? GuSizes.bottomNavHeight : 0,
      child: ColoredBox(
        // Sütun dışı zemin (geniş ekran) ve bant üstündeki güvenli alan.
        color: context.gu.colors.bgCanvas,
        child: GuContentColumn(
          child: OfflineBanner(
            // Prototip bandı yalnızca uygulama kabuğunda gösterir
            // (`nav.mode === 'app'`).
            enabled: GuTab.ofLocation(location) != null,
            child: MaintenanceBanner(child: AppGate(child: content)),
          ),
        ),
      ),
    );
  }
}
