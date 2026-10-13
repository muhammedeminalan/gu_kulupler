import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/di/app_provider_mixin.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_demo_accounts.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_menu_state.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_menu_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/intl.dart';

/// DebugMenu paneli (K-E, CD-69) — tasarım kimliği yoktur; prototipteki
/// kontrol panelinin (mock, K-02) yalnızca `AppEnvironment.debugMenuEnabled`
/// derlemesindeki karşılığıdır. Rota `/debug` (R14).
///
/// Bölümler: tema, dil, metin ölçeği; **demo hesaplar** (yalnızca
/// [isEmulator]; CD-132 (23)) — hesaba dokunmak seed'deki hesapla oturum açar
/// ve uygulamaya gider (nereye varılacağına router karar verir); oturum
/// açıksa "Çıkış yap"; sistem ekranlarına (SYS-02 / 03 / 04) kısayollar.
/// Anahtarlar `debug.*` biçimindedir (`GuKey.action` değil — tasarım aksiyon
/// envanterine girmez).
// TODO(T-43): çevrimdışı simülasyonu, boş / hata zorlama.
class DebugMenuView extends ConsumerWidget with AppProviderStateMixin {
  /// DebugMenu paneli. [isEmulator] yalnızca testte verilir (bayrak derleme
  /// sabitidir).
  const DebugMenuView({
    this.isEmulator = AppEnvironment.isEmulator,
    super.key,
  });

  /// Emülatör derlemesi mi? Demo hesaplar bölümü yalnızca bu durumda ağaca
  /// girer ve giriş yalnızca bu durumda denenir.
  final bool isEmulator;

  /// Geri düğmesinin anahtarı.
  static const Key backKey = ValueKey<String>('debug.back');

  /// Demo hesap giriş hatası satırının anahtarı.
  static const Key demoErrorKey = ValueKey<String>('debug.demo.error');

  /// "Çıkış yap" satırının anahtarı.
  static const Key signOutKey = ValueKey<String>('debug.signOut');

  /// SYS-02 kısayolunun anahtarı.
  static const Key errorScreenKey = ValueKey<String>('debug.screen.error');

  /// SYS-03 kısayolunun anahtarı.
  static const Key offlineScreenKey = ValueKey<String>('debug.screen.offline');

  /// SYS-04 kısayolunun anahtarı.
  static const Key notFoundScreenKey = ValueKey<String>(
    'debug.screen.notFound',
  );

  /// "Sistem dili" seçeneğinin kimliği.
  static const String systemLocaleId = 'system';

  /// Tema seçeneğinin anahtarı.
  static Key themeKey(ThemeMode mode) =>
      ValueKey<String>('debug.theme.${mode.name}');

  /// Dil seçeneğinin anahtarı ([id]: dil kodu ya da [systemLocaleId]).
  static Key localeKey(String id) => ValueKey<String>('debug.locale.$id');

  /// Metin ölçeği seçeneğinin anahtarı.
  static Key textScaleKey(GuTextScaleLevel level) =>
      ValueKey<String>('debug.textScale.${level.name}');

  /// Demo hesap satırının anahtarı ([id]: `u_ayse` …).
  static Key demoAccountKey(String id) => ValueKey<String>('debug.demo.$id');

  static String _roleLabel(AppLocalizations l10n, DebugDemoRole role) =>
      switch (role) {
        DebugDemoRole.student => l10n.roleStudent,
        DebugDemoRole.member => l10n.roleMember,
        DebugDemoRole.board => l10n.roleBoard,
        DebugDemoRole.president => l10n.rolePresident,
        DebugDemoRole.advisor => l10n.roleAdvisor,
        DebugDemoRole.superadmin => l10n.roleSuperadmin,
      };

  /// Satır sonu: girişi süren hesapta dönen gösterge, oturumdaki hesapta
  /// onay işareti.
  static Widget? _accountTrailing(
    AppLocalizations l10n,
    DebugMenuState state,
    DebugDemoAccount account,
    String? uid,
  ) {
    if (state.signingInId == account.id) {
      return GuSpinner(semanticLabel: l10n.commonLoading);
    }
    if (uid == account.id) {
      return const GuIcon(GuIcons.check, size: GuSizes.icon20);
    }
    return null;
  }

  Future<void> _signInDemo(
    BuildContext context,
    WidgetRef ref,
    DebugDemoAccount account,
  ) async {
    final signedIn = await ref
        .read(debugMenuViewModelProvider.notifier)
        .signInDemo(account, isEmulator: isEmulator);
    if (!signedIn || !context.mounted) return;
    const ClubsRoute().go(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(debugMenuViewModelProvider);
    final viewModel = ref.read(debugMenuViewModelProvider.notifier);
    final uid = sessionOf(ref).uid;
    final l10n = context.l10n;
    final percent = NumberFormat.percentPattern(l10n.localeName);
    const locales = AppLocalizations.supportedLocales;
    final localeIds = <String>[
      systemLocaleId,
      for (final locale in locales) locale.languageCode,
    ];

    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.settingsGroupAppearance,
        onBack: () =>
            context.canPop() ? context.pop() : const ClubsRoute().go(context),
        backSemanticLabel: l10n.a11yBack,
        backActionKey: backKey,
      ),
      body: ListView(
        padding: GuInsets.only(
          bottom:
              MediaQuery.viewPaddingOf(context).bottom +
              GuSizes.screenScrollBottomExtra,
        ),
        children: [
          GuSectionTitle(
            title: l10n.settingsTheme,
            topMargin: GuSectionTitleMargin.first,
          ),
          Padding(
            padding: GuInsets.h16,
            child: GuSegmented(
              options: [
                for (final mode in ThemeMode.values)
                  GuSegmentOption(
                    id: mode.name,
                    label: switch (mode) {
                      ThemeMode.system => l10n.themeSystem,
                      ThemeMode.light => l10n.themeLight,
                      ThemeMode.dark => l10n.themeDark,
                    },
                  ),
              ],
              value: state.themeMode.name,
              onChanged: (id) =>
                  viewModel.setThemeMode(ThemeMode.values.byName(id)),
              optionKeyBuilder: (index) => themeKey(ThemeMode.values[index]),
            ),
          ),
          GuSectionTitle(title: l10n.settingsLanguage),
          Padding(
            padding: GuInsets.h16,
            child: GuSegmented(
              options: [
                GuSegmentOption(id: systemLocaleId, label: l10n.themeSystem),
                for (final locale in locales)
                  GuSegmentOption(
                    id: locale.languageCode,
                    label: locale.languageCode.toUpperCase(),
                  ),
              ],
              value: state.locale?.languageCode ?? systemLocaleId,
              onChanged: (id) => viewModel.setLocale(
                id == systemLocaleId ? null : Locale(id),
              ),
              optionKeyBuilder: (index) => localeKey(localeIds[index]),
            ),
          ),
          GuSectionTitle(title: l10n.settingsTextSize),
          Padding(
            padding: GuInsets.h16,
            child: GuSegmented(
              options: [
                for (final level in GuTextScaleLevel.values)
                  GuSegmentOption(
                    id: level.name,
                    label: percent.format(level.factor),
                  ),
              ],
              value: state.textScale.name,
              onChanged: (id) => viewModel.setTextScale(
                GuTextScaleLevel.values.byName(id),
              ),
              optionKeyBuilder: (index) =>
                  textScaleKey(GuTextScaleLevel.values[index]),
            ),
          ),
          if (isEmulator) ...[
            GuSectionTitle(title: l10n.debugMenuDemoAccounts),
            for (final account in DebugDemoAccounts.all)
              GuTile(
                key: demoAccountKey(account.id),
                title: _roleLabel(l10n, account.role),
                subtitle: account.email,
                trailing: _accountTrailing(l10n, state, account, uid),
                disabled: state.signingInId != null,
                onTap: () => _signInDemo(context, ref, account),
              ),
            if (state.errorCode case final code? when state.isError)
              Padding(
                padding: GuInsets.h16,
                child: GuBanner(
                  key: demoErrorKey,
                  kind: GuBannerKind.danger,
                  text: l10n.debugMenuSignInError(code),
                  card: true,
                ),
              ),
          ],
          if (uid != null) ...[
            GuSectionTitle(title: l10n.settingsGroupAccount),
            GuTile(
              key: signOutKey,
              title: l10n.authLogout,
              leading: GuIcon(
                GuIcons.logOut,
                size: GuSizes.icon20,
                color: context.gu.colors.stateDanger,
              ),
              danger: true,
              onTap: viewModel.signOut,
            ),
          ],
          GuSectionTitle(title: l10n.debugMenuSystemScreens),
          GuTile(
            key: errorScreenKey,
            title: l10n.sysErrorTitle,
            subtitle: AppPaths.error,
            chevron: true,
            onTap: () => const ErrorRoute().go(context),
          ),
          GuTile(
            key: offlineScreenKey,
            title: l10n.sysOfflineTitle,
            subtitle: AppPaths.offline,
            chevron: true,
            onTap: () => const OfflineRoute().go(context),
          ),
          GuTile(
            key: notFoundScreenKey,
            title: l10n.sysNotFoundTitle,
            subtitle: AppPaths.notFound,
            chevron: true,
            onTap: () => const NotFoundRoute().go(context),
          ),
        ],
      ),
    );
  }
}
