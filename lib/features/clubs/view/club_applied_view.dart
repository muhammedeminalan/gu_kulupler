import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/mixin/club_applied_view_mixin.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// "İsteğin kulüp yönetimine iletildi" ekranı — `ClubAppliedRoute`
/// (`/clubs/:clubId/applied`); prototip `Applied`
/// (`screens-clubs.js:115–121`). Başvuru gönderilince (SHT-05) açılır.
///
/// Çubuk: kapat (başlıksız). Gövde ortalı sütundur (yatay 16, üst 16, aralık
/// 16): onay işareti 110 · başlık · açıklama · başvuru kartı (küçük amblem,
/// kulüp adı, "Gönderildi: {tarih}", varsa not alıntısı) · bildirim izni
/// yoksa "Sonucu kaçırma — bildirimleri aç." kartı ("Aç" → DLG-03) · "Diğer
/// kulüplere göz at" · "Başvurularım".
///
/// Onay mesajı ve düğmeler veriden bağımsızdır; yalnızca başvuru kartı
/// kulübe ve nota bağlıdır: okunurken iskelet, okunamazsa "Yeniden dene"li
/// hata bandı çizilir. Kulüp yoksa SYS-04'e gidilir. Alt boşluk gerçek
/// güvenli alan + 8'dir (K-07). Davranış `ClubAppliedViewMixin`'dedir.
///
/// Design: CLB-04
class ClubAppliedView extends ConsumerStatefulWidget {
  /// [clubId] kulübüne yapılan başvurunun onay ekranı.
  const ClubAppliedView({required this.clubId, super.key});

  /// Kulüp kimliği (`ClubAppliedRoute.clubId`).
  final String clubId;

  @override
  ConsumerState<ClubAppliedView> createState() => _ClubAppliedViewState();
}

class _ClubAppliedViewState extends ConsumerState<ClubAppliedView>
    with ClubAppliedViewMixin {
  /// `screens-clubs.js:117` `SuccessCheck size=110` —
  /// `GuSizes.successCheckSizes` (72 · 110) içindeki CLB-04 değeri.
  static final double _checkSize = GuSizes.successCheckSizes[1];

  /// Kayıtta olmayan ikon adında amblemin yedeği.
  static const GuIcons _fallbackIcon = GuIcons.users;

  /// Başvuru kartı (`screens-clubs.js:118`): amblem + ad + gönderim anı,
  /// altında not alıntısı.
  Widget _applicationCard(
    ClubApplicationState state,
    ClubModel club,
    AppLocalizations l10n,
  ) {
    final gu = context.gu;
    final clock = ref.watch(appClockProvider);
    final formats = AppDateFormats(Localizations.localeOf(context), clock);
    // Oturumdaki üyelik henüz gelmediyse başvuru "şimdi" gönderilmiştir.
    final sentAt = state.membership?.appliedAt ?? clock.nowUtc();
    final note = state.savedNote.trim();
    return GuCard(
      padding: GuCard.bodyPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSpacing.s8,
        children: [
          Row(
            spacing: GuSpacing.s12,
            children: [
              GuEmblem(icon: CoverMapper.icon(club.iconName) ?? _fallbackIcon),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.name, style: gu.text.titleS),
                    Text(
                      l10n.appliedSentAt(formats.dateTime(l10n, sentAt)),
                      style: gu.text.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (note.isNotEmpty)
            Text(
              l10n.appliedNoteQuote(note),
              style: gu.text.bodyS.copyWith(
                color: gu.colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  /// Başvuru kartının yeri: hata bandı → iskelet → kart.
  Widget _applicationSlot(ClubApplicationState state, AppLocalizations l10n) {
    if (state.isError) {
      return GuBanner(
        kind: GuBannerKind.danger,
        text: l10n.sysErrorDesc,
        actionLabel: l10n.commonRetry,
        onAction: retry,
        actionKey: GuKey.action('CLB-04.retry'),
      );
    }
    final club = state.club;
    if (club == null) {
      return GuCard(
        child: GuSkeletonList(semanticLabel: l10n.commonLoading, count: 1),
      );
    }
    return _applicationCard(state, club, l10n);
  }

  /// "Sonucu kaçırma — bildirimleri aç." kartı (`screens-clubs.js:119`).
  Widget _notificationCard(AppLocalizations l10n) {
    final gu = context.gu;
    return GuCard(
      muted: true,
      padding: GuCard.bodyPadding,
      child: Row(
        spacing: GuSpacing.s12,
        children: [
          GuIcon(
            GuIcons.bellRing,
            size: GuSizes.icon22,
            color: gu.colors.brandPrimaryText,
          ),
          Expanded(
            child: Text(l10n.appliedEnableNotif, style: gu.text.bodyS),
          ),
          GuButton(
            key: GuKey.action('CLB-04.enableNotifications'),
            label: l10n.commonOpen,
            variant: GuButtonVariant.tonal,
            size: GuButtonSize.sm,
            onPressed: enableNotifications,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(clubApplicationViewModelProvider(widget.clubId));
    watchNotFound();

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        onBack: close,
        closeIcon: true,
        backSemanticLabel: l10n.a11yClose,
        backActionKey: GuKey.action('CLB-04.close'),
      ),
      // Kulüp yoksa SYS-04'e gidiliyor: başarı mesajı gösterilmez.
      body: state.isNotFound
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: GuInsets.only(
                left: GuSpacing.s16,
                top: GuSpacing.s16,
                right: GuSpacing.s16,
                bottom:
                    MediaQuery.paddingOf(context).bottom +
                    GuSizes.screenScrollBottomExtra,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: GuSpacing.s16,
                children: [
                  Center(
                    child: GuSuccessCheck(
                      size: _checkSize,
                      semanticLabel: l10n.commonSuccess,
                    ),
                  ),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.appliedTitle,
                      style: gu.text.titleL,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    l10n.appliedDesc,
                    style: gu.text.bodyM.copyWith(
                      color: gu.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  _applicationSlot(state, l10n),
                  if (state.showNotificationPrompt) _notificationCard(l10n),
                  GuButton(
                    key: GuKey.action('CLB-04.browse'),
                    label: l10n.appliedBrowse,
                    size: GuButtonSize.lg,
                    full: true,
                    onPressed: browse,
                  ),
                  Center(
                    child: GuButton(
                      key: GuKey.action('CLB-04.myApplications'),
                      label: l10n.appliedMyApplications,
                      variant: GuButtonVariant.text,
                      onPressed: openMyApplications,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
