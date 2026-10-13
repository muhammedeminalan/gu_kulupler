import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/mixin/club_application_view_mixin.dart';
import 'package:gu_kulupler/features/clubs/view/widget/application_status_card.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_ui/gu_ui.dart';

/// Başvuru durumu ekranı — `ClubApplicationRoute`
/// (`/clubs/:clubId/application`); prototip `ApplicationStatus`
/// (`screens-clubs.js:124–138`).
///
/// Çubuk: geri + "Başvuru durumu". Gövde (yatay 16, üst 8, alt 24, aralık
/// 20): kulüp kartı + üç adımlı zaman çizelgesi (`ApplicationStatusCard`),
/// ardından başvurunun evresine göre:
///
/// * **Beklemede:** "Notun" (çok satırlı, 300 karakter, sayaçlı) · "Kaydet"
///   (not değişene kadar kapalı; TST-07) · "İsteği iptal et" (DLG-07 →
///   TST-40 → kulüp sayfası).
/// * **Reddedildi / Çıkarıldı:** neden kartı (varsa) · yeniden başvuru
///   rozeti + kalan gün · "Tekrar başvur" (bekleme sürerken ve kulüp başvuru
///   almıyorken kapalı görünür; dokununca TST-X4 / TST-X1) · bekleme notu.
/// * **Onaylandı:** "Üyeliğin onaylandı." bandı · "Kulübe git".
/// * **Başvuru yok** (hiç başvurulmamış, iptal edilmiş, ayrılınmış): bilgi
///   bandı · "Katıl".
///
/// Üyelik oturumdan canlı gelir: yönetici karar verince ekran kendiliğinden
/// evre değiştirir. Durumlar: okunamadı → hata + "Yeniden dene"; okunuyor →
/// iskelet; kulüp yok → SYS-04. Alt boşluk gerçek güvenli alan + 8'dir
/// (K-07); klavye açıkken içerik kayar. Davranış
/// `ClubApplicationViewMixin`'dedir.
///
/// Design: CLB-05
class ClubApplicationView extends ConsumerStatefulWidget {
  /// [clubId] kulübündeki başvurunun durumu.
  const ClubApplicationView({required this.clubId, super.key});

  /// Kulüp kimliği (`ClubApplicationRoute.clubId`).
  final String clubId;

  @override
  ConsumerState<ClubApplicationView> createState() =>
      _ClubApplicationViewState();
}

class _ClubApplicationViewState extends ConsumerState<ClubApplicationView>
    with ClubApplicationViewMixin {
  /// Beklemede: not alanı, "Kaydet", "İsteği iptal et"
  /// (`screens-clubs.js:132`).
  List<Widget> _pending(ClubApplicationState state, AppLocalizations l10n) => [
    GuInput(
      actionKey: GuKey.action('CLB-05.note'),
      controller: noteController,
      label: l10n.applicationYourNote,
      multiline: true,
      maxLength: Limits.applicationNoteMax,
      showCounter: true,
      errorText: noteErrorText(state, l10n),
      onChanged: viewModel.setNote,
    ),
    // Alana bağlanamayan hata düğmenin altında gösterilir.
    GuField(
      errorText: submitErrorText(state, l10n),
      child: GuButton(
        key: GuKey.action('CLB-05.saveNote'),
        label: l10n.commonSave,
        variant: GuButtonVariant.tonal,
        full: true,
        loading: state.isSaving,
        disabled: !state.canSaveNote,
        onPressed: saveNote,
      ),
    ),
    GuButton(
      key: GuKey.action('CLB-05.cancel'),
      label: l10n.applicationCancel,
      variant: GuButtonVariant.dangerOutline,
      full: true,
      loading: state.isCancelling,
      onPressed: () => unawaited(cancel()),
    ),
  ];

  /// Reddedildi / çıkarıldı: neden kartı, yeniden başvuru rozeti, "Tekrar
  /// başvur", bekleme notu (`screens-clubs.js:133–135`).
  List<Widget> _closed(
    ClubApplicationState state,
    ClubModel club,
    AppLocalizations l10n,
  ) {
    final gu = context.gu;
    final membership = state.membership;
    final reason = membership?.rejectReason;
    final rejectNote = membership?.rejectNote ?? '';
    final retryAfter = state.retryAfter;
    final clock = ref.watch(appClockProvider);
    final relative = RelativeTimeFormatter(l10n, clock);
    return [
      if (reason != null)
        GuCard(
          muted: true,
          padding: GuCard.bodyPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s4,
            children: [
              Text(
                l10n.applicationReason.upperFor(
                  Localizations.localeOf(context),
                ),
                style: gu.text.overline,
              ),
              Text(_reasonLabel(reason, l10n), style: gu.text.bodyM),
              if (rejectNote.isNotEmpty)
                Text(
                  rejectNote,
                  style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
                ),
            ],
          ),
        ),
      if (retryAfter == null)
        _reapplyBlock(club, l10n, relative, retryAfter: null, canRetry: true)
      else
        // Bekleme dolunca rozet ve düğme kendiliğinden açılır.
        GuCountdown(
          until: retryAfter,
          now: clock.nowUtc,
          builder: (context, remaining) => _reapplyBlock(
            club,
            l10n,
            relative,
            retryAfter: retryAfter,
            canRetry: remaining <= Duration.zero,
          ),
        ),
    ];
  }

  /// Yeniden başvuru rozeti + kalan gün, "Tekrar başvur" ve bekleme notu.
  Widget _reapplyBlock(
    ClubModel club,
    AppLocalizations l10n,
    RelativeTimeFormatter relative, {
    required DateTime? retryAfter,
    required bool canRetry,
  }) {
    final gu = context.gu;
    final waitingUntil = canRetry ? null : retryAfter;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s20,
      children: [
        Wrap(
          spacing: GuSpacing.s8,
          runSpacing: GuSpacing.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GuBadge(
              kind: waitingUntil == null
                  ? GuBadgeKind.success
                  : GuBadgeKind.pending,
              icon: GuIcons.hourglass,
              label: waitingUntil == null
                  ? l10n.applicationCanReapply
                  : l10n.applicationRetryAt(dateFormats.date(waitingUntil)),
            ),
            if (waitingUntil != null)
              Text(relative.countdown(waitingUntil), style: gu.text.caption),
          ],
        ),
        GuButton(
          key: GuKey.action('CLB-05.reapply'),
          label: l10n.applicationReapply,
          full: true,
          disabled: waitingUntil != null || !club.applicationsOpen,
          onPressed: () => unawaited(reapply()),
          onDisabledPressed: () => unawaited(reapply()),
        ),
        if (waitingUntil != null)
          Text(l10n.applicationRetryNote, style: gu.text.caption),
      ],
    );
  }

  /// Onaylandı: başarı bandı + "Kulübe git" (`screens-clubs.js:136`).
  List<Widget> _approved(AppLocalizations l10n) => [
    GuBanner(kind: GuBannerKind.success, text: l10n.applicationApprovedNote),
    GuButton(
      key: GuKey.action('CLB-05.openClub'),
      label: l10n.applicationGoClub,
      full: true,
      onPressed: openClub,
    ),
  ];

  /// Başvuru yok: bilgi bandı + "Katıl" (`screens-clubs.js:137`).
  List<Widget> _none(ClubApplicationState state, AppLocalizations l10n) => [
    GuBanner(text: l10n.applicationNoneNote),
    GuField(
      errorText: submitErrorText(state, l10n),
      child: GuButton(
        key: GuKey.action('CLB-05.reapply'),
        label: l10n.clubsCardJoin,
        full: true,
        loading: state.isJoining,
        onPressed: () => unawaited(reapply()),
      ),
    ),
  ];

  /// Ret nedeninin adı (`rejectReason.*`).
  String _reasonLabel(RejectReason reason, AppLocalizations l10n) =>
      switch (reason) {
        RejectReason.quota => l10n.rejectReasonQuota,
        RejectReason.criteria => l10n.rejectReasonCriteria,
        RejectReason.missing => l10n.rejectReasonMissing,
        RejectReason.other => l10n.rejectReasonOther,
      };

  Widget _content(
    ClubApplicationState state,
    ClubModel club,
    AppLocalizations l10n,
  ) => SingleChildScrollView(
    padding: GuInsets.only(
      left: GuSpacing.s16,
      top: GuSpacing.s8,
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
        ApplicationStatusCard(
          club: club,
          phase: state.phase,
          membership: state.membership,
          onOpenClub: openClub,
        ),
        ...switch (state.phase) {
          ApplicationPhase.pending => _pending(state, l10n),
          ApplicationPhase.rejected ||
          ApplicationPhase.removed => _closed(state, club, l10n),
          ApplicationPhase.approved => _approved(l10n),
          ApplicationPhase.none => _none(state, l10n),
        },
      ],
    ),
  );

  /// Okunamadı: hata durumu, kalan alanda dikeyde ortalı; sığmazsa kayar.
  Widget _error(AppLocalizations l10n) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: GuInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom +
            GuSizes.screenScrollBottomExtra,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            onRetry: retry,
            retryActionKey: GuKey.action('CLB-05.retry'),
          ),
        ),
      ),
    ),
  );

  /// Koşullu gövde: kulüp yok → boş (SYS-04'e gidiliyor); hata; iskelet;
  /// içerik.
  Widget _body(ClubApplicationState state, AppLocalizations l10n) {
    if (state.isNotFound) return const SizedBox.shrink();
    if (state.isError) return _error(l10n);
    final club = state.club;
    if (club == null) {
      return SingleChildScrollView(
        padding: GuInsets.only(top: GuSpacing.s8),
        child: GuSkeletonList(semanticLabel: l10n.commonLoading),
      );
    }
    return _content(state, club, l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(clubApplicationViewModelProvider(widget.clubId));
    watchNotFound();

    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.applicationTitle,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('CLB-05.back'),
      ),
      body: _body(state, l10n),
    );
  }
}
