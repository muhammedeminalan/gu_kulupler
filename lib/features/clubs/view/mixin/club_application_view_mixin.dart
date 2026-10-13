import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_application_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/join_application_sheet.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';

/// CLB-05 davranışı: not alanının denetleyicisi, gezinme, iptal, yeniden
/// başvuru ve hata metni eşlemesi (prototip `ApplicationStatus`,
/// `screens-clubs.js:124–138`).
///
/// * Not alanı ViewModel'deki notla eşlenir: sunucudan okunan not alana
///   yazılır, yazılan her harf ViewModel'e gider.
/// * Geri (`CLB-05.back`) yığındaki önceki sayfaya (kulüp), yığın yoksa kulüp
///   sayfasına döner. İstek iptal edilince de aynı yere dönülür
///   (`dialogs.js:22`).
/// * "Tekrar başvur" / "Katıl" (`CLB-05.reapply`): ViewModel yolu seçer;
///   form gerekiyorsa SHT-05 burada açılır. Başvuru gönderilince CLB-04'e
///   gidilir; onaysız kulübe katılındıysa TST-34 gösterilir ("Kulübe git" →
///   kulüp sayfası).
/// * Kulüp yok / silinmişse SYS-04'e gidilir.
mixin ClubApplicationViewMixin on ConsumerState<ClubApplicationView> {
  /// "Notun" alanının denetleyicisi.
  late final TextEditingController noteController;

  /// Ekranın ViewModel'i.
  ClubApplicationViewModel get viewModel =>
      ref.read(clubApplicationViewModelProvider(widget.clubId).notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    final provider = clubApplicationViewModelProvider(widget.clubId);
    final initial = ref.read(provider);
    noteController = TextEditingController(text: initial.note);
    // Sunucudan okunan (ya da yeniden başvuruyla değişen) not alana yazılır;
    // kullanıcının yazdığı metin zaten aynıdır (yeniden yazılmaz).
    ref.listenManual(provider.select((state) => state.note), (_, note) {
      if (noteController.text != note) noteController.text = note;
    });
    // Ekran, kulübün yokluğu zaten bilinirken açıldıysa (ViewModel canlıydı).
    if (initial.isNotFound) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goNotFound());
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  /// `build` içinde çağrılır: kulüp yok / silinmiş çıkarsa SYS-04'e gider.
  void watchNotFound() => ref.listen(
    clubApplicationViewModelProvider(
      widget.clubId,
    ).select((state) => state.isNotFound),
    (_, isNotFound) {
      if (isNotFound) _goNotFound();
    },
  );

  /// Etkin dilin tarih biçimleri (saat `AppClock`'tan).
  AppDateFormats get dateFormats => AppDateFormats(
    Localizations.localeOf(context),
    ref.read(appClockProvider),
  );

  /// Geri (`CLB-05.back`): önceki sayfa; yığın yoksa kulüp sayfası.
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      openClub();
    }
  }

  /// Kulüp kartı ve "Kulübe git" (`CLB-05.openClub`) → CLB-03.
  void openClub() => ClubDetailRoute(clubId: widget.clubId).go(context);

  /// "Kaydet" (`CLB-05.saveNote`) → TST-07.
  void saveNote() => unawaited(viewModel.saveNote());

  /// "İsteği iptal et" (`CLB-05.cancel`) → DLG-07 → TST-40 → geri.
  Future<void> cancel() async {
    final cancelled = await viewModel.cancel();
    if (cancelled && mounted) goBack();
  }

  /// "Tekrar başvur" / "Katıl" (`CLB-05.reapply`); düğme devre dışı
  /// görünürken de çağrılır (TST-X1 / TST-X4 nedenini söyler).
  Future<void> reapply() async {
    final outcome = await viewModel.reapply(
      formatDate: dateFormats.date,
      onOpenClub: _openClubFromToast,
    );
    if (!mounted || outcome != ReapplyOutcome.openSheet) return;
    final clubId = widget.clubId;
    final result = await _feedback.showSheet<JoinApplicationOutcome>(
      SheetId.sht05,
      builder: (_) => JoinApplicationSheet(clubId: clubId),
    );
    if (!mounted) return;
    switch (result) {
      case JoinApplicationOutcome.applied:
        ClubAppliedRoute(clubId: clubId).go(context);
      case JoinApplicationOutcome.joined:
        viewModel.showJoined(onOpenClub: _openClubFromToast);
      case JoinApplicationOutcome.invalid ||
          JoinApplicationOutcome.offline ||
          JoinApplicationOutcome.closed ||
          JoinApplicationOutcome.cooldown ||
          JoinApplicationOutcome.failed ||
          JoinApplicationOutcome.ignored ||
          null:
        // Sayfa gönderim olmadan kapandı.
        break;
    }
  }

  /// Hata durumundaki "Yeniden dene" (`CLB-05.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Not alanının altında gösterilecek hata metni; hata yoksa `null`. Sınır
  /// aşımı sayaçla gösterilir ("Kaydet" kapalıdır), ayrı metni yoktur.
  String? noteErrorText(ClubApplicationState state, AppLocalizations l10n) =>
      state.errors[ApplicationField.note] == FormFieldError.required
      ? l10n.authErrRequired
      : null;

  /// Alana bağlanamayan yazım hatasının metni (düğmenin altında); ağ hatası
  /// toast ile bildirildiği için satır içi gösterilmez.
  String? submitErrorText(ClubApplicationState state, AppLocalizations l10n) =>
      state.submitError == SubmitError.unknown ? l10n.sysErrorTitle : null;

  /// TST-34 "Kulübe git": toast ekran kapandıktan sonra da durabilir.
  void _openClubFromToast() {
    if (mounted) openClub();
  }

  void _goNotFound() {
    if (mounted) const NotFoundRoute().go(context);
  }
}
