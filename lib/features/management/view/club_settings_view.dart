import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_state.dart';
import 'package:gu_kulupler/features/management/view/mixin/club_settings_view_mixin.dart';
import 'package:gu_kulupler/features/management/view/widget/club_settings_form.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kulüp ayarları — `ClubSettingsRoute` (`/clubs/:clubId/manage/settings`);
/// MGT-01 hızlı eylemi, CLB-03 "Kulüp ayarları" ve faaliyet satırı açar
/// (guard `V`, router'da). Prototip `S['MGT-09']`
/// (`screens-manage.js:170–188`).
///
/// Yukarıdan aşağıya: `ManageHeader` (geri · "Kulüp ayarları" · kulüp adı ·
/// rol rozeti) · danışmanda salt okunur bandı (kaydırma dışında) · kaydırma
/// alanı (`col gap20 px16 pt8 pb24`): gönderim hatası bandı +
/// `ClubSettingsForm` (Görünüm · Bilgiler · İletişim · Katılım · Danışman) ·
/// alt çubuk "Kaydet" (değişiklik yokken kapalı → TST-X9; danışmanda kapalı
/// → TST-26; kaydederken döner).
///
/// * Durum sırası: hata ("Yeniden dene", `MGT-09.retry`) → yükleniyor
///   (iskelet) → form. Boş durum yoktur (form). Çevrimdışı bandı kökte
///   çizilir; form ekranda kalır, kaydet TST-24 verir.
/// * Ayarları düzenleyemeyen ve danışman olmayan kullanıcı (rolsüz süper
///   admin) formu görmez: kilit çizimi + "Bu paneli görüntüleme yetkin yok."
///   (prototip `NoAccess`; ad / kategori / görsel süper adminde ADM-03).
/// * Kaydedilmemiş değişiklikte geri → DLG-25 (`UnsavedChangesMixin`).
/// * Klavye açıkken içerik kayar (`resizeToAvoidBottomInset` + kaydırma).
///
/// Davranış `ClubSettingsViewModel` ve `ClubSettingsViewMixin`'dedir.
///
/// Design: MGT-09
class ClubSettingsView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün ayarları.
  const ClubSettingsView({required this.clubId, super.key});

  /// Kulüp kimliği (`ClubSettingsRoute.clubId`).
  final String clubId;

  @override
  ConsumerState<ClubSettingsView> createState() => _ClubSettingsViewState();
}

class _ClubSettingsViewState extends ConsumerState<ClubSettingsView>
    with UnsavedChangesMixin<ClubSettingsView>, ClubSettingsViewMixin {
  /// Prototip `NoAccess` (`screens-manage.js:11`).
  Widget _noAccess() {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      appBar: GuAppBar(
        onBack: leaveScreen,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('MGT-09.back'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: GuEmptyState(
            illustration: GuIllustrations.locked,
            description: l10n.mgtNoAccess,
          ),
        ),
      ),
    );
  }

  Widget _cta(ClubSettingsState state) => GuStickyCta(
    children: [
      GuButton(
        key: GuKey.action('MGT-09.save'),
        label: context.l10n.commonSave,
        loading: state.isSubmitting,
        disabled: !state.isDirty || state.isReadOnly,
        onPressed: () => unawaited(save()),
        onDisabledPressed: viewModel.onSaveDisabledTap,
      ),
    ],
  );

  Widget _form(ClubSettingsState state) => SingleChildScrollView(
    padding: GuInsets.only(
      left: GuSpacing.s16,
      right: GuSpacing.s16,
      top: GuSpacing.s8,
      bottom: GuSpacing.s24,
    ),
    child: ClubSettingsForm(
      state: state,
      onLogoTap: () => unawaited(openLogo()),
      onCoverTap: () => unawaited(openCover()),
      onLockedNameTap: viewModel.onLockedNameTap,
      onCategoryTap: () => unawaited(openCategory()),
      onSummaryChanged: viewModel.setSummary,
      onAboutChanged: viewModel.setAbout,
      onEmailChanged: viewModel.setEmail,
      onInstagramChanged: viewModel.setInstagram,
      onWebChanged: viewModel.setWeb,
      onApplicationsOpenChanged: (value) =>
          viewModel.setApplicationsOpen(value: value),
      onApprovalRequiredChanged: (value) =>
          viewModel.setApprovalRequired(value: value),
      onRequireNoteChanged: (value) => viewModel.setRequireNote(value: value),
      onReadOnlyTap: viewModel.onReadOnlyTap,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(provider);
    final session = ref.watch(sessionViewModelProvider);
    if (!state.canView) return _noAccess();
    final canSwitch = ManagedClubPickerSheet.managedOf(session).length > 1;

    // Sıra: hata → yükleniyor → form (boş durum yoktur).
    final hasForm = !state.isError && !state.isLoading;
    final Widget body;
    if (state.isError) {
      body = Center(
        child: SingleChildScrollView(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            retryActionKey: GuKey.action('MGT-09.retry'),
            onRetry: retry,
          ),
        ),
      );
    } else if (state.isLoading) {
      body = SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: GuSkeletonList(
          semanticLabel: l10n.commonLoading,
          count: 1,
          variant: GuSkeletonVariant.card,
        ),
      );
    } else {
      body = _form(state);
    }

    return buildUnsavedGuard(
      child: Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        appBar: ManageHeader(
          club: state.original,
          title: l10n.clubSettingsTitle,
          onBack: onBack,
          backKey: GuKey.action('MGT-09.back'),
          role: state.role,
          isSuperAdmin: session.isSuperAdmin,
          onSwitchClub: canSwitch ? switchClub : null,
          switchClubKey: canSwitch ? GuKey.action('MGT-09.switchClub') : null,
        ),
        bottomNavigationBar: hasForm ? _cta(state) : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isReadOnly)
              GuBanner(
                kind: GuBannerKind.readonly,
                text: l10n.mgtReadOnlyBanner,
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
