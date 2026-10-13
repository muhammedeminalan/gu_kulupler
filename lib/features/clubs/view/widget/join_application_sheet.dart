import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-05 "Katılma başvurusu" — kulübe katılma başvurusu formu (prototip
/// `SHEETS['SHT-05']`, `sheets.js:27–32`). CLB-01 ve CLB-03 açar.
///
/// * Gövde: kulüp satırı (amblem + ad + "kategori · Onay gerekli"), çok
///   satırlı not alanı (otomatik odak, sayaçlı; sınır
///   `Limits.applicationNoteMax`, fazlası kesilir; yardım metni kulüp not
///   istiyorsa "Zorunlu", değilse "İsteğe bağlı"), bilgi satırı + KVKK
///   bağlantısı (AUT-06, `push`). Alt alanda büyük "Başvuruyu gönder".
/// * Yeniden başvuru bekleme süresi sürüyorsa düğme kalan günü yazar ve
///   devre dışıdır; dokunmak TST-X4'ü gösterir.
/// * Gönderim `JoinApplicationViewModel.submit`'tedir. Sayfa yalnızca
///   başarıda, sonuçla kapanır: [JoinApplicationOutcome.applied] (çağıran
///   CLB-04'e gider) ya da [JoinApplicationOutcome.joined] (çağıran TST-34
///   gösterir). Reddedilen yollarda (TST-X1, TST-X4, TST-24, alan / sunucu
///   hatası) açık kalır.
/// * Not doluyken X / scrim / sürükleme / geri DLG-25'i sorar (prototip
///   `dirty`); "Kaydetmeden çık" → `null` ile kapanır.
/// * Kulüp okunurken iskelet, okunamazsa hata + "Yeniden dene" çizilir.
/// * Anahtarlar `SHT-05.note`, `SHT-05.legal`, `SHT-05.submit`,
///   `SHT-05.close` (+ `SHT-05.scrim`, `FeedbackService`; hata durumunda
///   `SHT-05.retry`).
///
/// ```dart
/// final outcome = await feedback.showSheet<JoinApplicationOutcome>(
///   SheetId.sht05,
///   builder: (_) => JoinApplicationSheet(clubId: clubId),
/// );
/// ```
///
/// Design: SHT-05
class JoinApplicationSheet extends ConsumerStatefulWidget {
  /// [clubId] kulübüne katılma başvurusu formu.
  const JoinApplicationSheet({required this.clubId, super.key});

  /// Başvurulan kulübün kimliği (`JoinApplicationViewModel` ailesi).
  final String clubId;

  @override
  ConsumerState<JoinApplicationSheet> createState() =>
      _JoinApplicationSheetState();
}

class _JoinApplicationSheetState extends ConsumerState<JoinApplicationSheet> {
  final TextEditingController _note = TextEditingController();

  JoinApplicationViewModelProvider get _provider =>
      joinApplicationViewModelProvider(widget.clubId);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// `sheets.js:31` `setNote(v.slice(0, 300))`: sınırı aşan metin kesilir
  /// (yapıştırma dahil), sayaç sınırı geçmez.
  void _onNoteChanged(String value) {
    final note = JoinApplicationViewModel.clampNote(value);
    if (note != value) {
      _note.value = TextEditingValue(
        text: note,
        selection: TextSelection.collapsed(offset: note.length),
      );
    }
    ref.read(_provider.notifier).setNote(note);
  }

  Future<void> _submit() async {
    final formats = AppDateFormats(
      Localizations.localeOf(context),
      ref.read(appClockProvider),
    );
    final outcome = await ref
        .read(_provider.notifier)
        .submit(formatDate: formats.date);
    if (!mounted) return;
    if (outcome == JoinApplicationOutcome.applied ||
        outcome == JoinApplicationOutcome.joined) {
      context.pop(outcome);
    }
  }

  /// Kapanma kapısı: not boşsa doğrudan kapanır; doluysa DLG-25 sorar.
  /// Gönderim sürerken sayfa kapanmaz.
  Future<bool> _confirmClose() async {
    final state = ref.read(_provider);
    if (state.isSubmitting) return false;
    if (!state.isDirty) return true;
    final answer = await showUnsavedChangesDialog(
      ref.read(feedbackServiceProvider),
    );
    return answer == UnsavedChangesResult.discard;
  }

  void _openLegal() =>
      unawaited(const LegalRoute(tip: LegalTab.kvkk).push<void>(context));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(_provider);
    final clock = ref.watch(appClockProvider);
    final club = state.club;
    final retryAfter = state.retryAfter;
    final isWaiting = retryAfter != null && state.isWaiting(clock.nowUtc());

    return GuSheetFrame(
      title: l10n.sht05Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-05.close'),
      onWillClose: _confirmClose,
      footer: club == null
          ? null
          : [
              GuButton(
                key: GuKey.action('SHT-05.submit'),
                label: isWaiting
                    ? RelativeTimeFormatter(l10n, clock).countdown(retryAfter)
                    : l10n.sht05Submit,
                size: GuButtonSize.lg,
                loading: state.isSubmitting,
                disabled: isWaiting,
                onPressed: _submit,
                onDisabledPressed: _submit,
              ),
            ],
      // Koşullu sıra: hata → yükleniyor → form.
      body: club != null
          ? _form(context, state, club)
          : state.isError
          ? GuErrorState(
              title: l10n.sysErrorTitle,
              description: l10n.sysErrorDesc,
              retryLabel: l10n.commonRetry,
              retryActionKey: GuKey.action('SHT-05.retry'),
              inline: true,
              onRetry: ref.read(_provider.notifier).fetch,
            )
          : GuSkeletonList(semanticLabel: l10n.commonLoading, count: 2),
    );
  }

  /// `.col.gap16.pb16` (sheets.js:30).
  Widget _form(
    BuildContext context,
    JoinApplicationState state,
    ClubModel club,
  ) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    return Padding(
      padding: GuInsets.only(bottom: GuSpacing.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s16,
        children: [
          Row(
            spacing: GuSpacing.s12,
            children: [
              GuEmblem(icon: CoverMapper.icon(club.iconName)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.name, style: gu.text.titleS),
                    Text(
                      l10n.sht05ClubMeta(
                        StaticLabels.category(context, club.categoryId),
                        state.isInstant
                            ? l10n.clubTypeInstant
                            : l10n.clubTypeApproval,
                      ),
                      style: gu.text.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          GuInput(
            controller: _note,
            label: l10n.sht05Why,
            multiline: true,
            maxLength: Limits.applicationNoteMax,
            showCounter: true,
            autofocus: true,
            help: state.requireNote ? l10n.commonRequired : l10n.commonOptional,
            errorText: _noteErrorText(state, l10n),
            actionKey: GuKey.action('SHT-05.note'),
            onChanged: _onNoteChanged,
          ),
          // Sunucu hatası bilgi satırının altında, alan hatası biçiminde.
          GuField(
            errorText: state.submitError == null ? null : l10n.sysErrorTitle,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: GuSpacing.s8,
              children: [
                GuIcon(
                  GuIcons.info,
                  size: GuSizes.icon18,
                  color: colors.textMuted,
                ),
                Expanded(
                  child: GuLinkText(
                    style: gu.text.bodyS.copyWith(color: colors.textSecondary),
                    spans: [
                      GuLinkSpan.text('${l10n.sht05Privacy} '),
                      GuLinkSpan.link(
                        l10n.legalKvkkShort,
                        actionKey: GuKey.action('SHT-05.legal'),
                        onTap: _openLegal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String? _noteErrorText(
    JoinApplicationState state,
    AppLocalizations l10n,
  ) => switch (state.errors[JoinApplicationField.note]) {
    null => null,
    FormFieldError.required => l10n.authErrRequired,
    _ => l10n.sysErrorTitle,
  };
}
