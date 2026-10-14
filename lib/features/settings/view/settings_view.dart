import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/di/app_version_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/settings/view/mixin/settings_view_mixin.dart';
import 'package:gu_kulupler/features/settings/view/widget/settings_row.dart';
import 'package:gu_kulupler/features/settings/view/widget/theme_sheet.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/language_sheet.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/mixin/sign_out_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-01 Ayarlar — `SettingsRoute` (`/profile/settings`); prototip
/// `Settings` (`screens-profile.js:60–70`).
///
/// Başlık çubuğu (geri · "Ayarlar") · kaydırma alanı (`.col.gap20.pb24`),
/// beş grup (`SettingsGroup`: büyük harfli overline + kart):
///
/// 1. Görünüm — Tema (seçili tema; SHT-17) · Dil (etkin dil; SHT-01) ·
///    Yazı boyutu bölmesi (%100 / %130 / %160) + önizleme cümlesi.
/// 2. Bildirimler — Bildirim tercihleri (NTF-02).
/// 3. Gizlilik ve güvenlik — Engellenen kullanıcılar (SET-02) · Gizlilik
///    Politikası / KVKK (AUT-06) · Şifre değiştir (SHT-32).
/// 4. Destek — Yardım ve destek (SET-05) · Hakkında (SET-04).
/// 5. Hesap — Çıkış yap (DLG-06; ok yok) · Hesabı sil (SET-03; yıkıcı).
///
/// En altta ortalı sürüm satırı (`v1.0.0`; prototipteki "(demo)" eki mock'tur).
/// Ekranın yükleniyor / boş / hata durumu yoktur (yerel tercihler).
///
/// Ayrı ViewModel yoktur (PLAN §12.12): `AppPreferencesViewModel` (tema / dil
/// / ölçek) + `SessionViewModel.signOut` (`SignOutMixin`); davranış
/// `SettingsViewMixin`'dedir.
///
/// Design: SET-01
class SettingsView extends ConsumerStatefulWidget {
  /// Ayarlar.
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView>
    with SignOutMixin<SettingsView>, SettingsViewMixin {
  /// "Gizlilik Politikası / KVKK" (`SET-01.privacy`) → AUT-06 gizlilik
  /// sekmesi (prototip `{tab:'gizlilik'}`), guard'sız geçici sayfa (`push`;
  /// PLAN §13.10 izinli dosya).
  void _openPrivacy() => unawaited(
    const LegalRoute(tip: LegalTab.gizlilik).push<void>(context),
  );

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final prefs = ref.watch(appPreferencesViewModelProvider);
    final version = ref.watch(appVersionProvider);

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.settingsTitle,
        onBack: back,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('SET-01.back'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: GuInsets.only(bottom: GuSpacing.s24),
            sliver: SliverList.list(
              children: [
                for (final (index, section) in [
                  _appearance(l10n, prefs.themeMode, prefs.textScale),
                  SettingsGroup(
                    title: l10n.navNotifications,
                    children: [
                      SettingsRow(
                        key: GuKey.action('SET-01.notifications'),
                        icon: GuIcons.bell,
                        title: l10n.notifPrefsTitle,
                        onTap: openNotificationPrefs,
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.settingsGroupPrivacy,
                    children: [
                      SettingsRow(
                        key: GuKey.action('SET-01.blocked'),
                        icon: GuIcons.ban,
                        title: l10n.blockedTitle,
                        onTap: openBlocked,
                      ),
                      SettingsRow(
                        key: GuKey.action('SET-01.privacy'),
                        icon: GuIcons.shield,
                        title: l10n.settingsPrivacyPolicy,
                        onTap: _openPrivacy,
                      ),
                      SettingsRow(
                        key: GuKey.action('SET-01.password'),
                        icon: GuIcons.keyRound,
                        title: l10n.settingsChangePassword,
                        onTap: openChangePassword,
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.settingsGroupSupport,
                    children: [
                      SettingsRow(
                        key: GuKey.action('SET-01.support'),
                        icon: GuIcons.lifeBuoy,
                        title: l10n.supportTitle,
                        onTap: openSupport,
                      ),
                      SettingsRow(
                        key: GuKey.action('SET-01.about'),
                        icon: GuIcons.info,
                        title: l10n.aboutTitle,
                        onTap: openAbout,
                      ),
                    ],
                  ),
                  SettingsGroup(
                    title: l10n.settingsGroupAccount,
                    children: [
                      SettingsRow(
                        key: GuKey.action('SET-01.logout'),
                        icon: GuIcons.logOut,
                        title: l10n.authLogout,
                        chevron: false,
                        onTap: logout,
                      ),
                      SettingsRow(
                        key: GuKey.action('SET-01.delete'),
                        icon: GuIcons.trash2,
                        title: l10n.deleteAccountTitle,
                        danger: true,
                        onTap: openDeleteAccount,
                      ),
                    ],
                  ),
                  if (version.isNotEmpty)
                    Text(
                      l10n.sysSplashVersion(version),
                      textAlign: TextAlign.center,
                      style: gu.text.caption,
                    ),
                ].indexed) ...[
                  if (index > 0) GuGap.v20,
                  section,
                ],
              ],
            ),
          ),
          const SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  /// "Görünüm" grubu: tema · dil · yazı boyutu.
  Widget _appearance(
    AppLocalizations l10n,
    ThemeMode themeMode,
    GuTextScaleLevel textScale,
  ) => SettingsGroup(
    title: l10n.settingsGroupAppearance,
    children: [
      SettingsRow(
        key: GuKey.action('SET-01.theme'),
        icon: GuIcons.sun,
        title: l10n.settingsTheme,
        subtitle: ThemeSheet.labelOf(l10n, themeMode),
        onTap: openTheme,
      ),
      SettingsRow(
        key: GuKey.action('SET-01.language'),
        icon: GuIcons.languages,
        title: l10n.settingsLanguage,
        subtitle: LanguageOptions.nameOf(l10n, Localizations.localeOf(context)),
        onTap: openLanguage,
      ),
      _SettingsTextScale(
        value: textScale,
        onChanged: setTextScale,
        formatPercent: AppDateFormats(
          Localizations.localeOf(context),
          ref.watch(appClockProvider),
        ).percent,
      ),
    ],
  );
}

/// Yazı boyutu bölümü — `.col.gap8.p16` (`screens-profile.js:65`): başlık
/// satırı (20 px `file-text` + "Yazı boyutu" · "Aa"), bölmeli seçici
/// (%100 / %130 / %160; yüzde yerel ayara göre, CD-101) ve önizleme cümlesi
/// (`bodyM`, `text.secondary`).
class _SettingsTextScale extends StatelessWidget {
  const _SettingsTextScale({
    required this.value,
    required this.onChanged,
    required this.formatPercent,
  });

  final GuTextScaleLevel value;
  final ValueChanged<GuTextScaleLevel> onChanged;
  final String Function(num value) formatPercent;

  /// Bölme anahtarları, [GuTextScaleLevel.values] sırasıyla (prototip
  /// `id: '1' | '1.3' | '1.6'`).
  static final List<Key> _keys = [
    GuKey.action('SET-01.textScale.1'),
    GuKey.action('SET-01.textScale.1.3'),
    GuKey.action('SET-01.textScale.1.6'),
  ];

  /// Yüzde değeri (100 / 130 / 160).
  static const int _percent = 100;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    return Padding(
      padding: GuInsets.all16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s8,
        children: [
          Row(
            spacing: GuSpacing.s12,
            children: [
              GuIcon(
                GuIcons.fileText,
                size: GuSizes.icon20,
                color: colors.brandPrimaryText,
              ),
              Expanded(
                child: Text(
                  context.l10n.settingsTextSize,
                  style: gu.text.bodyM.copyWith(color: colors.textHeading),
                ),
              ),
              ExcludeSemantics(
                // ignore-hardcode: yazı örneği glifi, çevrilmez (screens-profile.js:65 "Aa")
                child: Text('Aa', style: gu.text.caption),
              ),
            ],
          ),
          GuSegmented(
            options: [
              for (final level in GuTextScaleLevel.values)
                GuSegmentOption(
                  id: level.name,
                  label: formatPercent((level.factor * _percent).round()),
                ),
            ],
            value: value.name,
            optionKeyBuilder: (index) => _keys[index],
            onChanged: (id) => onChanged(GuTextScaleLevel.values.byName(id)),
          ),
          Text(
            context.l10n.settingsTextPreview,
            style: gu.text.bodyM.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
