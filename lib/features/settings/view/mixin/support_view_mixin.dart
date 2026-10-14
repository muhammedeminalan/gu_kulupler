import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/settings/provider/support_state.dart';
import 'package:gu_kulupler/features/settings/provider/support_view_model.dart';
import 'package:gu_kulupler/features/settings/view/support_view.dart';
import 'package:gu_kulupler/features/settings/view/widget/support_faq_list.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-05 davranışı: mesaj denetleyicisi, konu menüsü, ek (SHT-16),
/// gönderim ve çıkış (prototip `Support`, `screens-profile.js:107–122`).
///
/// * Konu (`SET-05.subject`): açılır menü (`PopMenu id="SET-05"`, sabit sağ
///   üst — CD-83); seçili konuda onay işareti.
/// * Ek (`SET-05.attach`): SHT-16 kamera / galeri; ek varken "Fotoğrafı
///   kaldır" da sunulur (en çok 1 ek — yeni seçim öncekinin yerine geçer).
/// * Gönder (`SET-05.send`) → `SupportViewModel.submit`.
/// * Geri (`SET-05.back`) ve sistem geri tuşu: gönderilmemiş girdi varsa
///   DLG-25 ("Kaydetmeden çık" / "Düzenlemeye devam"; "Kaydet" yok).
mixin SupportViewMixin on UnsavedChangesMixin<SupportView> {
  /// `imageTooLarge` metnindeki `{maxMb}` için bayt → MB böleni.
  static const int _bytesPerMb = 1024 * 1024;

  /// Konu menüsünün saydam scrim'i (`ui.js:191` `PopMenu id="SET-05"`).
  static final Key scrimKey = GuKey.action('SET-05.scrim');

  /// Mesaj alanı.
  late final TextEditingController messageController;

  ProviderSubscription<String>? _messageSubscription;

  /// Ekranın ViewModel'i.
  SupportViewModel get viewModel => ref.read(supportViewModelProvider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  bool get isDirty =>
      ref.watch(supportViewModelProvider.select((s) => s.isDirty));

  /// Önceki sayfa; yığın yoksa Ayarlar (SET-01).
  @override
  void leaveScreen() {
    if (context.canPop()) {
      context.pop();
    } else {
      const SettingsRoute().go(context);
    }
  }

  @override
  void initState() {
    super.initState();
    messageController = TextEditingController(
      text: ref.read(supportViewModelProvider).message,
    );
    // Mesaj ViewModel'den de değişir: sınırda kesilir, "Yeni talep" sıfırlar.
    _messageSubscription = ref.listenManual(
      supportViewModelProvider.select((s) => s.message),
      (_, message) => _show(messageController, message),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.close();
    messageController.dispose();
    super.dispose();
  }

  /// Geri (`SET-05.back`); gönderim sürerken etkisizdir.
  void onBack() {
    if (ref.read(supportViewModelProvider).isSubmitting) return;
    unawaited(confirmLeave());
  }

  /// Konu alanı (`SET-05.subject`): konu menüsü.
  Future<void> openSubjectMenu() async {
    final state = ref.read(supportViewModelProvider);
    if (state.isSubmitting) return;
    final l10n = AppLocalizations.of(context);
    final subject = await _feedback.showMenu<SupportSubject>(
      scrimKey: scrimKey,
      items: [
        for (final subject in SupportSubject.values)
          GuPopMenuItem(
            key: subjectKeyOf(subject),
            label: subjectLabel(l10n, subject),
            selected: subject == state.subject,
            value: subject,
          ),
      ],
    );
    if (subject != null && mounted) viewModel.setSubject(subject);
  }

  /// Ek düğmesi (`SET-05.attach`): SHT-16 → kamera / galeri / kaldır.
  Future<void> openAttachmentSource() async {
    final state = ref.read(supportViewModelProvider);
    if (state.isSubmitting) return;
    final choice = await _feedback.showSheet<PhotoSourceChoice>(
      SheetId.sht16,
      builder: (_) => PhotoSourceSheet(hasPhoto: state.attachment != null),
    );
    if (!mounted) return;
    switch (choice) {
      case PhotoSourceChoice.camera:
        await viewModel.attach(MediaSource.camera);
      case PhotoSourceChoice.gallery:
        await viewModel.attach(MediaSource.gallery);
      case PhotoSourceChoice.remove:
        viewModel.removeAttachment();
      case null:
        break;
    }
  }

  /// "Gönder" (`SET-05.send`): başarıda klavye kapanır (başarı kartı).
  Future<void> send() async {
    final outcome = await viewModel.submit();
    if (outcome == SupportSubmitOutcome.sent && mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  /// SSS satırları: sıra, ARB metni ve arama süzgeci.
  List<SupportFaqItem> faqItems(SupportState state, AppLocalizations l10n) => [
    for (final index in SupportState.faqIndexes)
      if (_faqOf(l10n, index) case (
        final question,
        final answer,
      ) when state.matchesFaq(question, answer))
        (index: index, question: question, answer: answer),
  ];

  /// [field] alanının hata metni; hata yoksa `null`.
  String? errorTextOf(
    SupportField field,
    SupportState state,
    AppLocalizations l10n,
  ) {
    final error = state.errors[field];
    if (error == null) return null;
    return switch (field) {
      SupportField.subject || SupportField.message => l10n.authErrRequired,
      // Seçici yalnızca iki tür hata üretir: boyut sınırı ya da işlenemeyen
      // görsel.
      SupportField.attachment =>
        error == FormFieldError.limitExceeded
            ? l10n.imageTooLarge(Limits.imageMaxBytes ~/ _bytesPerMb)
            : l10n.imageInvalidType,
    };
  }

  /// Alana bağlanamayan gönderim hatasının metni (ağ / yetki hatası toast
  /// ile bildirilir).
  String? submitErrorTextOf(SupportState state, AppLocalizations l10n) =>
      state.submitError == SupportError.unknown ? l10n.sysErrorTitle : null;

  /// [subject] menü öğesinin anahtarı (`SET-05.subject.<json>`).
  static Key subjectKeyOf(SupportSubject subject) =>
      GuKey.action('SET-05.subject.${subject.json}');

  /// [subject] konusunun görünen adı (`support.subject.<json>`).
  static String subjectLabel(AppLocalizations l10n, SupportSubject subject) =>
      switch (subject) {
        SupportSubject.bug => l10n.supportSubjectBug,
        SupportSubject.suggestion => l10n.supportSubjectSuggestion,
        SupportSubject.account => l10n.supportSubjectAccount,
        SupportSubject.club => l10n.supportSubjectClub,
        SupportSubject.other => l10n.supportSubjectOther,
      };

  /// [index]. sorunun (soru, cevap) metni (`faq.q<n>` / `faq.a<n>`).
  static (String, String) _faqOf(AppLocalizations l10n, int index) =>
      switch (index) {
        1 => (l10n.faqQ1, l10n.faqA1),
        2 => (l10n.faqQ2, l10n.faqA2),
        3 => (l10n.faqQ3, l10n.faqA3),
        4 => (l10n.faqQ4, l10n.faqA4),
        5 => (l10n.faqQ5, l10n.faqA5),
        6 => (l10n.faqQ6, l10n.faqA6),
        7 => (l10n.faqQ7, l10n.faqA7),
        _ => (l10n.faqQ8, l10n.faqA8),
      };

  /// [controller] alanındaki metni [value] yapar (imleç sonda).
  static void _show(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
