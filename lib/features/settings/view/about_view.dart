import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/settings/constants/about_content.dart';
import 'package:gu_kulupler/features/settings/provider/about_view_model.dart';
import 'package:gu_kulupler/features/settings/view/widget/about_sections.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-04 "Hakkında" — `AboutRoute` (`/profile/settings/about`); prototip
/// `About` (`screens-profile.js:95–103`). Sistem / tanınmayan bildirimin
/// hedefidir (W-30, PLAN §13.7).
///
/// Yukarıdan aşağıya (yatay 16, kartlar arası 20, alt 24 + güvenli alan):
/// başlık çubuğu (geri · "Hakkında") · amblem 80 + "GÜ Kulüpler" +
/// "v{sürüm}" (kullanıcı kararı 2026-10-16: "· Demo sürümü" yok) + açıklama
/// (ortalı, en çok 300) · "Ekip" kartı ·
/// "Açık kaynak lisansları" kartı (açılır satırlar) · "Sürüm notları" kartı
/// (açılır) · Kullanım Koşulları / Gizlilik Politikası / Yardım ve destek
/// kartı.
///
/// * Lisans satırı açılınca açıklama + "Lisansı görüntüle" (DLG-32 → dış
///   adres) görünür; "Sürüm notları" açılınca 4 madde.
/// * Ekip satırı (kullanıcı kararı 2026-10-16: tek kişi + GitHub) DLG-32 →
///   GitHub profilini açar.
/// * Koşullar / gizlilik AUT-06'yı geçici sayfa olarak açar (`push` —
///   guard'sız, PLAN §13.10); destek SET-05'e gider (`go`).
/// * Ekran veri okumaz (sürüm paketten); yükleniyor / boş / hata durumu
///   yoktur. Çevrimdışı bandı kökte çizilir.
///
/// Design: SET-04
class AboutView extends ConsumerWidget {
  /// Hakkında.
  const AboutView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(aboutViewModelProvider);
    final viewModel = ref.read(aboutViewModelProvider.notifier);
    final titleStyle = gu.text.titleM;
    final version = l10n.sysSplashVersion(state.version);

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.aboutTitle,
        onBack: () => context.canPop()
            ? context.pop()
            : const SettingsRoute().go(context),
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('SET-04.back'),
      ),
      body: SingleChildScrollView(
        padding: GuInsets.only(
          left: GuSpacing.s16,
          right: GuSpacing.s16,
          bottom:
              GuSpacing.s24 +
              MediaQuery.paddingOf(context).bottom +
              GuSizes.screenScrollBottomExtra,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s20,
          children: [
            Padding(
              padding: GuInsets.only(top: GuSpacing.s8),
              child: Column(
                spacing: GuSpacing.s8,
                children: [
                  GuLogo(size: GuSizes.logoSizes[2]),
                  Semantics(
                    header: true,
                    child: Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: titleStyle.copyWith(
                        letterSpacing:
                            (titleStyle.fontSize ?? 0) *
                            AboutContent.titleLetterSpacingEm,
                      ),
                    ),
                  ),
                  Text(
                    version,
                    textAlign: TextAlign.center,
                    style: gu.text.caption,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AboutContent.descriptionMaxWidth,
                    ),
                    child: Text(
                      l10n.aboutDesc,
                      textAlign: TextAlign.center,
                      style: gu.text.bodyS.copyWith(
                        color: gu.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AboutTeamCard(
              onOpenGithub: (member) =>
                  unawaited(viewModel.openTeamGithub(member)),
            ),
            AboutLicensesCard(
              isOpen: state.isLicenseOpen,
              onToggle: viewModel.toggleLicense,
              onOpenLink: (license) =>
                  unawaited(viewModel.openLicense(license)),
            ),
            AboutReleaseNotesCard(
              version: version,
              isOpen: state.isReleaseNotesOpen,
              onToggle: viewModel.toggleReleaseNotes,
            ),
            AboutLinksCard(
              onTerms: () => unawaited(
                const LegalRoute(tip: LegalTab.kosullar).push<void>(context),
              ),
              onPrivacy: () => unawaited(
                const LegalRoute(tip: LegalTab.gizlilik).push<void>(context),
              ),
              onSupport: () => const SupportRoute().go(context),
            ),
          ],
        ),
      ),
    );
  }
}
