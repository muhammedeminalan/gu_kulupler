import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-10'da doğrulanmış şikayet — sayfanın `pop` değeri.
///
/// `ReportRepository.report(reporterId:, target:, reason:, note:)` çağrısının
/// girdileridir: çağıran yalnızca şikayet edeni ekler.
final class ReportReasonResult extends Equatable {
  /// [target] için [reason] nedenli şikayet; [note] kırpılmış açıklamadır.
  const ReportReasonResult({
    required this.target,
    required this.reason,
    this.note = '',
  });

  /// Şikayet edilen şey (sayfayı açanın verdiği hedef, aynen).
  final ReportTarget target;

  /// Seçilen neden.
  final ReportReason reason;

  /// Açıklama: yalnızca [ReportReason.other] nedeninde doludur (orada
  /// zorunlu), diğer nedenlerde boş dizgidir.
  final String note;

  @override
  List<Object?> get props => [target, reason, note];
}

/// SHT-10 gönderiminin sonucu ([ReportReasonSheet.onSubmit]).
enum ReportSubmitOutcome {
  /// Şikayet yazıldı ya da aynı hedef zaten bildirilmiş: sayfa sonuçla
  /// kapanır, çağıran DLG-12'yi açar.
  sent,

  /// Yazılamadı (oturum yok, çevrimdışı TST-24, yetki TST-X18, beklenmeyen
  /// hata — geri bildirimi çağıran gösterdi): sayfa açık kalır.
  failed,

  /// Günlük şikayet sınırı doldu (`Limits.reportDailyLimit`; T-45, kullanıcı
  /// kararı 3): sayfa açık kalır, hata satırında `sht10DailyLimit`.
  /// Tasarımda karşılığı yok — mevcut hata satırı kullanılır.
  dailyLimit,
}

/// SHT-10 "Şikayet nedeni" — altı neden + "Diğer" için açıklama (prototip
/// `SHEETS['SHT-10']`, `sheets.js:49–52`). CLB-03, FED-01/02 (SHT-08),
/// SHT-27 ve EVT-02 açar; hedef türleri `ReportTargetType` (CD-33).
///
/// * Gövde: açıklama cümlesi, altı `GuOptionRow` (radyo;
///   `ReportReason.values` sırası), yalnızca "Diğer" seçiliyken çok satırlı
///   açıklama alanı (otomatik odak, sayaçlı; sınır `Limits.reportNoteMax`,
///   fazlası kesilir), altında hata satırı. Alt alanda yıkıcı "Şikayet et".
/// * Doğrulama gönderimde: neden yok → "Bu alan zorunlu"; "Diğer" + boş
///   açıklama → "…kısa bir açıklama yaz". Seçim ya da yazma hatayı siler.
/// * Sonuç [ReportReasonResult]'tır (`pop`). [onSubmit] verilirse önce o
///   beklenir: düğme meşgul görünür, [ReportSubmitOutcome.sent] → sayfa
///   sonuçla kapanır, [ReportSubmitOutcome.failed] → açık kalır (çevrimdışı
///   TST-24, yazma hatası), [ReportSubmitOutcome.dailyLimit] → açık kalır ve
///   hata satırında günlük sınır metni (`sht10DailyLimit` — T-45). Verilmezse
///   doğrulanan seçim doğrudan döner. Yazma ve DLG-12 çağıranın işidir.
/// * Bir neden seçiliyken X / scrim / sürükleme / geri DLG-25'i sorar
///   (prototip `dirty`); "Kaydetmeden çık" → `null` ile kapanır.
/// * Anahtarlar `SHT-10.reason.<neden>`, `SHT-10.note`, `SHT-10.submit`,
///   `SHT-10.close` (+ `SHT-10.scrim`, `FeedbackService`).
///
/// ```dart
/// final report = await feedback.showSheet<ReportReasonResult>(
///   SheetId.sht10,
///   builder: (_) => ReportReasonSheet(
///     target: (type: ReportTargetType.club, id: club.id, clubId: club.id),
///   ),
/// );
/// ```
///
/// Design: SHT-10
class ReportReasonSheet extends ConsumerStatefulWidget {
  /// [target] hedefi için şikayet nedeni sorar.
  const ReportReasonSheet({required this.target, this.onSubmit, super.key});

  /// Şikayet edilen şey; sonuca aynen taşınır.
  final ReportTarget target;

  /// Gönderim: [ReportSubmitOutcome.sent] → sayfa sonuçla kapanır, diğerleri
  /// → açık kalır ([ReportSubmitOutcome.dailyLimit] hata satırını gösterir).
  /// Beklenen süre boyunca "Şikayet et" meşgul görünür. `null` → doğrulanan
  /// seçim doğrudan sonuç olur.
  final Future<ReportSubmitOutcome> Function(ReportReasonResult result)?
  onSubmit;

  /// [reason] satırının anahtarı (`SHT-10.reason.<neden>`).
  static Key reasonKey(ReportReason reason) =>
      FeedbackKeys.of(SheetId.sht10.designId, 'reason.${reason.json}');

  /// Açıklama alanının anahtarı (`SHT-10.note`).
  static final Key noteKey = FeedbackKeys.of(SheetId.sht10.designId, 'note');

  /// "Şikayet et" düğmesinin anahtarı (`SHT-10.submit`).
  static final Key submitKey = FeedbackKeys.of(
    SheetId.sht10.designId,
    'submit',
  );

  /// [reason] nedeninin görünen adı (`reportReason.<neden>`).
  static String reasonLabel(AppLocalizations l10n, ReportReason reason) =>
      switch (reason) {
        ReportReason.spam => l10n.reportReasonSpam,
        ReportReason.harassment => l10n.reportReasonHarassment,
        ReportReason.inappropriate => l10n.reportReasonInappropriate,
        ReportReason.misinformation => l10n.reportReasonMisinformation,
        ReportReason.offtopic => l10n.reportReasonOfftopic,
        ReportReason.other => l10n.reportReasonOther,
      };

  @override
  ConsumerState<ReportReasonSheet> createState() => _ReportReasonSheetState();
}

/// Gönderimde bulunan eksik.
enum _ReportFormError {
  /// Neden seçilmedi.
  reasonRequired,

  /// "Diğer" seçili, açıklama boş.
  noteRequired,

  /// Günlük şikayet sınırı doldu (gönderim sonucu — T-45).
  dailyLimit,
}

class _ReportReasonSheetState extends ConsumerState<ReportReasonSheet> {
  final TextEditingController _note = TextEditingController();
  ReportReason? _reason;
  _ReportFormError? _error;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _select(ReportReason reason) => setState(() {
    _reason = reason;
    _error = null;
  });

  /// `sheets.js:52` `setNote(v.slice(0, max))`: sınırı aşan metin kesilir
  /// (yapıştırma dahil), sayaç sınırı geçmez.
  void _onNoteChanged(String value) {
    const max = Limits.reportNoteMax;
    if (value.length > max) {
      // Yarım kalan vekil çift (emoji) bırakılmaz.
      final end = _isHighSurrogate(value.codeUnitAt(max - 1)) ? max - 1 : max;
      final text = value.substring(0, end);
      _note.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (_error != null) setState(() => _error = null);
  }

  static bool _isHighSurrogate(int unit) =>
      unit >= _highSurrogateStart && unit <= _highSurrogateEnd;

  /// UTF-16 üst vekil aralığı (U+D800–U+DBFF).
  static const int _highSurrogateStart = 0xD800;
  static const int _highSurrogateEnd = 0xDBFF;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = _ReportFormError.reasonRequired);
      return;
    }
    // Açıklama yalnızca "Diğer" nedeninde görünür ve gönderilir.
    final note = reason == ReportReason.other ? _note.text.trim() : '';
    if (reason == ReportReason.other && note.isEmpty) {
      setState(() => _error = _ReportFormError.noteRequired);
      return;
    }
    final result = ReportReasonResult(
      target: widget.target,
      reason: reason,
      note: note,
    );
    final onSubmit = widget.onSubmit;
    if (onSubmit != null) {
      setState(() => _isSubmitting = true);
      final ReportSubmitOutcome outcome;
      try {
        outcome = await onSubmit(result);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      if (!mounted) return;
      switch (outcome) {
        case ReportSubmitOutcome.sent:
          break;
        case ReportSubmitOutcome.failed:
          return;
        case ReportSubmitOutcome.dailyLimit:
          setState(() => _error = _ReportFormError.dailyLimit);
          return;
      }
    }
    Navigator.of(context).pop(result);
  }

  /// Kapanma kapısı: seçim yoksa doğrudan kapanır; varsa DLG-25 sorar.
  /// Gönderim sürerken sayfa kapanmaz.
  Future<bool> _confirmClose() async {
    if (_isSubmitting) return false;
    if (_reason == null) return true;
    final answer = await showUnsavedChangesDialog(
      ref.read(feedbackServiceProvider),
    );
    return answer == UnsavedChangesResult.discard;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final errorText = switch (_error) {
      _ReportFormError.reasonRequired => l10n.authErrRequired,
      _ReportFormError.noteRequired => l10n.sht10OtherRequired,
      _ReportFormError.dailyLimit => l10n.sht10DailyLimit,
      null => null,
    };
    return GuSheetFrame(
      title: l10n.sht10Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht10.designId, 'close'),
      onWillClose: _confirmClose,
      footer: [
        GuButton(
          key: ReportReasonSheet.submitKey,
          label: l10n.sht10Submit,
          variant: GuButtonVariant.danger,
          loading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
      // `.col.gap8.pb16` (sheets.js:52); satırlar gövde dolgusunun içindedir
      // (etiket 32 dp'de başlar).
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s8,
          children: [
            Text(
              l10n.sht10Desc,
              style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
            ),
            for (final reason in ReportReason.values)
              GuOptionRow(
                key: ReportReasonSheet.reasonKey(reason),
                label: ReportReasonSheet.reasonLabel(l10n, reason),
                selected: _reason == reason,
                onTap: () => _select(reason),
              ),
            if (_reason == ReportReason.other)
              // `rows=3` prototipte de 4 satır çizilir (`textarea`
              // `min-height:88px`, css:169) → `GuInput` varsayılanı.
              GuInput(
                controller: _note,
                label: l10n.sht10Describe,
                multiline: true,
                maxLength: Limits.reportNoteMax,
                showCounter: true,
                autofocus: true,
                actionKey: ReportReasonSheet.noteKey,
                onChanged: _onNoteChanged,
              ),
            if (errorText != null) _ReportErrorLine(text: errorText),
          ],
        ),
      ),
    );
  }
}

/// Form hatası satırı — `.field-help.is-error` + `triangle-alert` 14
/// (`sheets.js:52`, css:171; `role="alert"` → canlı bölge). Bir alana bağlı
/// değildir (neden seçimi için de çıkar), bu yüzden `GuField` dışında çizilir.
class _ReportErrorLine extends StatelessWidget {
  const _ReportErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final danger = gu.colors.stateDanger;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSizes.fieldHelpGap,
        children: [
          GuIcon(
            GuIcons.triangleAlert,
            size: GuSizes.fieldHelpIcon,
            color: danger,
          ),
          Expanded(
            child: Text(text, style: gu.text.fieldHelp.copyWith(color: danger)),
          ),
        ],
      ),
    );
  }
}
