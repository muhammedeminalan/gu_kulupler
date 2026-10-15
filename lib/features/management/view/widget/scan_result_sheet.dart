import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-24'ün `pop` değeri. X / scrim / sürükleme / geri → `null` ("Sonraki
/// bilet" ile aynı: tarama sürer).
enum ScanResultSheetAction {
  /// "Sonraki bilet" ya da "Geçerli" sonucunun 2 sn sonra kendiliğinden
  /// kapanması (`AppDurations.qrSuccessAutoClose`).
  next,

  /// "Geri al" (yalnızca [ScanResultSheet.showUndo] iken): okutma geri
  /// alınır (`attended → going`).
  undo,
}

/// SHT-24 "Geçersiz bilet" açıklamasının nedeni.
enum ScanInvalidReason {
  /// Bilet bu etkinliğin değil ya da bulunamadı / iptal / kopya kod (W-79):
  /// `AttendanceRepository.scanTicket` yalnızca `ScanOutcome.invalid` döner;
  /// prototip elle kod bulunamayınca da bu metni gösterir
  /// (`screens-manage.js:148`) → "Bu bilet bu etkinliğe ait değil."
  notForEvent,

  /// İçerik hiç çözülemedi (`TicketScanRejection.malformed`) → "Kod
  /// okunamadı…" (`sht24Unreadable`; tasarımdaki `sht24InvalidNone`'ın
  /// ikinci cümlesi demo akışına ait — kullanılmaz).
  unreadable,

  /// Yoklama penceresi dışı (K-G; `FirestoreRuleCode.attendanceWindowClosed`)
  /// → `sht24WindowClosed` (`Limits.attendanceWindowBefore/After`).
  windowClosed,
}

/// SHT-24 "Tarama sonucu" — MGT-07 okutma / elle kod sonucu (prototip
/// `SHEETS['SHT-24']`, `sheets.js:114–116`).
///
/// * Başlık sonuca göre: Geçerli bilet · Zaten okutulmuş · Geçersiz bilet
///   ([outcome]); gövde ortalı: 72 px sonuç ikonu (başarı `circle-check` /
///   uyarı `check-check` / tehlike `circle-x`), [user] varsa avatar 48 + ad,
///   açıklama (geçerli → "Katıldı olarak işaretlendi."; zaten okutulmuş →
///   [scannedAt] saatiyle (Istanbul) + [scannedByName] varsa "Okutan: …";
///   geçersiz → [invalidReason] — bkz. [ScanInvalidReason]; verilmezse
///   [unreadable] → okunamadı, değilse "Bu bilet bu etkinliğe ait değil."),
///   geçerlide sayaç [counter] ("Katıldı a/b").
/// * Alt çubuk: [showUndo] ise "Geri al" (outline) + "Sonraki bilet".
/// * [ScanOutcome.valid] sonucu [AppDurations.qrSuccessAutoClose] sonra
///   kendiliğinden [ScanResultSheetAction.next] ile kapanır.
/// * Açıkken tarama durur (çağıran: `ScanViewModel` `isPaused`); kapanınca
///   sürer. Anahtarlar [nextKey], [undoKey], [closeKey].
///
/// ```dart
/// final action = await feedback.showSheet<ScanResultSheetAction>(
///   SheetId.sht24,
///   builder: (_) => ScanResultSheet(outcome: result.outcome, user: user),
/// );
/// ```
///
/// Design: SHT-24
class ScanResultSheet extends ConsumerStatefulWidget {
  /// [outcome] sonucunun sayfası.
  const ScanResultSheet({
    required this.outcome,
    this.user,
    this.avatarImage,
    this.scannedAt,
    this.counter,
    this.unreadable = false,
    this.showUndo = false,
    this.invalidReason,
    this.scannedByName,
    super.key,
  });

  /// Okutma sonucu.
  final ScanOutcome outcome;

  /// Biletin sahibi (geçerli / zaten okutulmuş); `null` → avatar ve ad yok.
  final UserModel? user;

  /// Sahibinin profil fotoğrafı; `null` → baş harfler.
  final ImageProvider? avatarImage;

  /// Önceki okutma anı (UTC; [ScanOutcome.alreadyScanned] açıklaması).
  final DateTime? scannedAt;

  /// Geçerli sonuçta sayaç: katılan / kayıtlı.
  final ({int attended, int registered})? counter;

  /// Geçersiz sonuçta içerik hiç çözülemedi mi (`TicketScanRejection
  /// .malformed`) — açıklama metnini seçer.
  final bool unreadable;

  /// "Geri al" düğmesi çizilsin mi (yalnızca geçerli sonuçta).
  final bool showUndo;

  /// Geçersiz sonucun nedeni; `null` → [unreadable]'dan türetilir.
  final ScanInvalidReason? invalidReason;

  /// Önceki okutmayı yapanın adı ([ScanOutcome.alreadyScanned]); `null` →
  /// satır çizilmez.
  final String? scannedByName;

  /// Açıklama metnini seçen geçersizlik nedeni.
  ScanInvalidReason get effectiveInvalidReason =>
      invalidReason ??
      (unreadable
          ? ScanInvalidReason.unreadable
          : ScanInvalidReason.notForEvent);

  /// "Sonraki bilet" düğmesinin anahtarı (`SHT-24.next`).
  static final Key nextKey = GuKey.action('SHT-24.next');

  /// "Geri al" düğmesinin anahtarı (`SHT-24.undo`).
  static final Key undoKey = GuKey.action('SHT-24.undo');

  /// Kapat düğmesinin anahtarı (`SHT-24.close`).
  static final Key closeKey = GuKey.action('SHT-24.close');

  @override
  ConsumerState<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends ConsumerState<ScanResultSheet> {
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    if (widget.outcome == ScanOutcome.valid) {
      _autoClose = Timer(
        AppDurations.qrSuccessAutoClose,
        () => _close(ScanResultSheetAction.next),
      );
    }
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  void _close(ScanResultSheetAction action) {
    _autoClose?.cancel();
    if (!mounted) return;
    context.pop<ScanResultSheetAction>(action);
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final outcome = widget.outcome;
    final title = switch (outcome) {
      ScanOutcome.valid => l10n.sht24Valid,
      ScanOutcome.alreadyScanned => l10n.sht24Used,
      ScanOutcome.invalid => l10n.sht24Invalid,
    };
    final (tone, icon) = switch (outcome) {
      ScanOutcome.valid => (GuIconBoxTone.success, GuIcons.circleCheck),
      ScanOutcome.alreadyScanned => (GuIconBoxTone.warning, GuIcons.checkCheck),
      ScanOutcome.invalid => (GuIconBoxTone.danger, GuIcons.circleX),
    };
    final description = switch (outcome) {
      ScanOutcome.valid => l10n.sht24ValidDesc,
      ScanOutcome.alreadyScanned => l10n.sht24UsedDesc(_scannedTime()),
      ScanOutcome.invalid => switch (widget.effectiveInvalidReason) {
        ScanInvalidReason.notForEvent => l10n.sht24InvalidDesc,
        ScanInvalidReason.unreadable => l10n.sht24Unreadable,
        ScanInvalidReason.windowClosed => l10n.sht24WindowClosed(
          Limits.attendanceWindowBefore.inHours,
          Limits.attendanceWindowAfter.inHours,
        ),
      },
    };
    final counter = outcome == ScanOutcome.valid ? widget.counter : null;
    final scannedBy = outcome == ScanOutcome.alreadyScanned
        ? widget.scannedByName
        : null;
    final user = widget.user;
    final live = user == null || user.isDeleted || user.isAnonymized
        ? null
        : user;
    final name = live?.name ?? l10n.commonDeletedUser;

    return GuSheetFrame(
      title: title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: ScanResultSheet.closeKey,
      footer: [
        if (widget.showUndo && outcome == ScanOutcome.valid)
          GuButton(
            key: ScanResultSheet.undoKey,
            label: l10n.commonUndo,
            variant: GuButtonVariant.outline,
            onPressed: () => _close(ScanResultSheetAction.undo),
          ),
        GuButton(
          key: ScanResultSheet.nextKey,
          label: l10n.sht24Next,
          onPressed: () => _close(ScanResultSheetAction.next),
        ),
      ],
      // sheets.js:116 `.col.gap12.pb16` ortalı.
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: GuSpacing.s12,
          children: [
            GuIconBox(
              icon: icon,
              tone: tone,
              size: GuSizes.notifIconLg,
              iconSize: GuSizes.notifIconLgIcon,
            ),
            if (user != null) ...[
              GuAvatar(
                initials: (live?.name ?? _unknown).initials,
                seed: live == null
                    ? _unknown
                    : (live.avatarSeed.isEmpty ? live.uid : live.avatarSeed),
                size: GuSizes.avatarSizes[5],
                image: live == null
                    ? null
                    : widget.avatarImage ??
                          ref.userAvatarImage(
                            live,
                            displaySize: GuSizes.avatarSizes[5],
                          ),
              ),
              Text(
                name,
                style: gu.text.titleS.copyWith(color: gu.colors.textHeading),
                textAlign: TextAlign.center,
              ),
            ],
            Text(
              description,
              style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (counter != null)
              Text(
                l10n.scanCounter(
                  counter.attended.toString(),
                  counter.registered.toString(),
                ),
                style: gu.text.caption.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            if (scannedBy != null && scannedBy.isNotEmpty)
              Text(
                l10n.sht24ScannedBy(scannedBy),
                style: gu.text.caption,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  /// Önceki okutmanın saati (İstanbul, yerel biçim); bilinmiyorsa şimdi
  /// (prototip `props.scannedAt || Date.now()`).
  String _scannedTime() {
    final clock = ref.read(appClockProvider);
    final formats = AppDateFormats(Localizations.localeOf(context), clock);
    return formats.time(widget.scannedAt ?? clock.nowUtc());
  }

  /// Silinmiş kullanıcının avatar metni ve renk tohumu (`art.js:44`).
  static const String _unknown = '?';
}
