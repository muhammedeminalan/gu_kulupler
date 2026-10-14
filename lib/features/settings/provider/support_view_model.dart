import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/provider/support_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'support_view_model.g.dart';

/// "Yardım ve destek" ekranının ViewModel'i (SET-05; PLAN §12
/// `SupportViewModel`; prototip `Support`, `screens-profile.js:107–122`).
///
/// * SSS: arama metni (`SET-05.search`) ve tek açık soru
///   (`SET-05.faq.<n>`); metinler ARB'dedir, süzme view'da
///   [SupportState.matchesFaq] ile.
/// * Form: konu (`SET-05.subject` → açılır menü), mesaj (`SET-05.message`,
///   `Limits.supportMessageMax`'ta kesilir), en çok bir ekran görüntüsü
///   (`SET-05.attach` → SHT-16; yeniden kodlama `DeviceImagePickerService`,
///   CD-135).
/// * Gönder (`SET-05.send`): doğrulama (konu + kırpılmış mesaj zorunlu) →
///   çevrimdışıysa TST-24 (`WriteGuardMixin`) → `SupportRepository
///   .createTicket` (numara üretimi ve ek yüklemesi repository içinde, PLAN
///   §6.1) → başarı: TST-23 `#GU-XXXXXX` + başarı kartı. Hata: form yerinde
///   kalır; ağ → TST-24, yetki → TST-X18, diğerleri günlüğe + form altı hata
///   satırı.
@riverpod
final class SupportViewModel extends _$SupportViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<SupportField>,
        PermissionPromptMixin {
  static const Set<StorageError> _networkUploadErrors = {
    StorageError.retryLimitExceeded,
    StorageError.timeout,
  };

  bool _isPicking = false;

  @override
  SupportState build() => const SupportState();

  /// SSS arama metni değişti (`SET-05.search`).
  void setFaqQuery(String query) {
    if (query == state.faqQuery) return;
    state = state.copyWith(faqQuery: query);
  }

  /// [index] sorusunu açar; açıksa kapatır (`SET-05.faq.<n>`). Başka bir
  /// soru açıksa o kapanır.
  void toggleFaq(int index) {
    state = state.expandedFaq == index
        ? state.copyWith(clearExpandedFaq: true)
        : state.copyWith(expandedFaq: index);
  }

  /// Konu seçildi (`SET-05.subject` menüsü).
  void setSubject(SupportSubject subject) {
    if (_isLocked || subject == state.subject) return;
    state = _edited(state.copyWith(subject: subject), SupportField.subject);
  }

  /// Mesaj değişti (`SET-05.message`); `Limits.supportMessageMax`'tan uzun
  /// metin kesilir (prototip `v.slice(0, 500)`).
  void setMessage(String value) {
    if (_isLocked) return;
    final message = _truncate(value, Limits.supportMessageMax);
    if (message == state.message) return;
    state = _edited(state.copyWith(message: message), SupportField.message);
  }

  /// [source] kaynağından ekran görüntüsü seçtirir (SHT-16 sonrası) ve
  /// varsa öncekinin yerine koyar (en çok 1).
  ///
  /// İzin ön açıklamaları ve kamera reddi (TST-32)
  /// `PermissionPromptMixin.pickImage` içindedir. Vazgeçme durumu
  /// değiştirmez; görsel işlenemezse ek alanına hata yazılır.
  Future<void> attach(MediaSource source) async {
    if (_isPicking || _isLocked) return;
    _isPicking = true;
    try {
      final result = await pickImage(source);
      if (!ref.mounted) return;
      switch (result) {
        case ImagePickSuccess(:final image):
          state = _edited(
            state.copyWith(attachment: image),
            SupportField.attachment,
          );
        case ImagePickCancelled() ||
            ImagePickFailure(error: ImagePickError.permissionDenied):
          break;
        case ImagePickFailure(:final error):
          AppLogger.warn('Destek eki seçilemedi: ${error.name}');
          state = state.copyWith(
            errors: {
              ...state.errors,
              SupportField.attachment: error == ImagePickError.tooLarge
                  ? FormFieldError.limitExceeded
                  : FormFieldError.invalidFormat,
            },
          );
      }
    } finally {
      _isPicking = false;
    }
  }

  /// Eklenen görseli kaldırır (SHT-16 "Fotoğrafı kaldır").
  void removeAttachment() {
    if (_isLocked || state.attachment == null) return;
    state = _edited(
      state.copyWith(clearAttachment: true),
      SupportField.attachment,
    );
  }

  /// Konu ve mesajı doğrular, hatalarını state'e yazar (ek hatası korunur);
  /// hata yoksa `true`.
  bool validate() {
    final errors = validateFields({
      SupportField.subject: () =>
          state.subject == null ? FormFieldError.required : null,
      SupportField.message: () => fromFieldError(
        FieldValidators.supportMessage(state.trimmedMessage),
      ),
    });
    state = state.copyWith(
      errors: {
        SupportField.attachment: ?state.errors[SupportField.attachment],
        ...errors,
      },
    );
    return errors.isEmpty;
  }

  /// "Gönder" (`SET-05.send`). Akış sınıf açıklamasında.
  Future<SupportSubmitOutcome> submit() async {
    final uid = ref.read(sessionViewModelProvider).uid;
    if (_isLocked || uid == null) return SupportSubmitOutcome.ignored;
    if (!validate()) return SupportSubmitOutcome.invalid;
    if (!ensureOnline()) return SupportSubmitOutcome.offline;

    final form = state;
    final subject = form.subject!;
    final attachment = form.attachment;
    state = form.copyWith(isSubmitting: true, clearSubmitError: true);

    final result = await supportRepository.createTicket(
      userId: uid,
      subject: subject,
      message: form.trimmedMessage,
      attachment: attachment == null
          ? null
          : SupportAttachment(
              bytes: attachment.bytes,
              contentType: attachment.contentType,
            ),
    );
    switch (result) {
      case FirebaseSuccess(:final data):
        feedback.showToast(
          ToastId.tst23,
          params: ToastParams(no: SupportState.displayOf(data.ticketNo)),
        );
        if (ref.mounted) {
          state = state.copyWith(isSubmitting: false, ticketNo: data.ticketNo);
        }
        return SupportSubmitOutcome.sent;
      case FirebaseFailure(:final error, :final message):
        final isNetwork =
            _networkUploadErrors.contains(error.storage) ||
            WriteGuardMixin.networkErrors.contains(error.firestore);
        // Yükleme adımının ağ hatası Storage türündedir: TST-24 doğrudan.
        if (isNetwork) feedback.showToast(ToastId.tst24);
        final firestore = error.firestore;
        final notified =
            isNetwork ||
            (firestore != null && showWriteFailureToast(firestore));
        if (!notified) {
          AppLogger.warn('Destek talebi gönderilemedi: $error', error: message);
        }
        if (ref.mounted) {
          state = state.copyWith(
            isSubmitting: false,
            submitError: notified ? null : SupportError.unknown,
          );
        }
        return SupportSubmitOutcome.failed;
    }
  }

  /// "Yeni talep" (başarı kartı): form sıfırlanır; SSS araması ve açık soru
  /// korunur (prototip `reset()` yalnızca formu sıfırlar).
  void newRequest() {
    if (state.isSubmitting) return;
    state = SupportState(
      faqQuery: state.faqQuery,
      expandedFaq: state.expandedFaq,
    );
  }

  /// Gönderim sürerken ya da talep gönderilmişken form değişmez.
  bool get _isLocked => state.isSubmitting || state.isSent;

  /// Düzenleme sonrası ortak güncelleme: [field] alanının hatası ve eski
  /// sunucu hatası silinir.
  static SupportState _edited(SupportState next, SupportField field) =>
      next.copyWith(
        clearSubmitError: true,
        errors: {
          for (final entry in next.errors.entries)
            if (entry.key != field) entry.key: entry.value,
        },
      );

  /// [value] metnini en çok [max] UTF-16 birimine keser; vekil çiftini
  /// bölmez.
  static String _truncate(String value, int max) {
    if (value.length <= max) return value;
    var end = max;
    final last = value.codeUnitAt(end - 1);
    // Yüksek vekil (0xD800–0xDBFF) çiftinin yarısı kalmasın.
    if (last >= _highSurrogateMin && last <= _highSurrogateMax) end--;
    return value.substring(0, end);
  }

  static const int _highSurrogateMin = 0xD800;
  static const int _highSurrogateMax = 0xDBFF;
}
