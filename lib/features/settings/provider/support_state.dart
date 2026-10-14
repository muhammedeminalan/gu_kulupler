import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;

/// Destek formunun hata taşıyabilen alanları (SET-05).
enum SupportField {
  /// Konu (`SET-05.subject`; zorunlu).
  subject,

  /// Mesaj (`SET-05.message`; kırpılmış 1–`Limits.supportMessageMax`).
  message,

  /// Ekran görüntüsü (`SET-05.attach`; seçilen görsel okunamadı /
  /// işlenemedi / sınırı aştı).
  attachment,
}

/// Gönderimin alana bağlanamayan başarısızlığı (ağ ve yetki hatası toast ile
/// bildirilir; bu değer formun altında hata satırı çizer).
enum SupportError {
  /// Diğer (geçersiz veri, Storage reddi…).
  unknown,
}

/// `SupportViewModel.submit` sonucu.
enum SupportSubmitOutcome {
  /// Talep yazıldı (TST-23; başarı kartı).
  sent,

  /// Doğrulama geçmedi (alan hataları state'te).
  invalid,

  /// Cihaz çevrimdışı; hiçbir şey yazılmadı (TST-24).
  offline,

  /// Sunucu reddetti ya da ulaşılamadı.
  failed,

  /// Süren bir gönderim varken, talep zaten gönderilmişken ya da oturum
  /// yokken gelen çağrı.
  ignored,
}

/// "Yardım ve destek" ekranının durumu (SET-05; PLAN §12 SupportViewModel;
/// prototip `Support`, `screens-profile.js:107–122`).
///
/// SSS araması ve açık soru ekran oturumu boyuncadır; form yalnızca
/// bellektedir. Gönderim başarısında [ticketNo] dolar ve form yerine başarı
/// kartı çizilir ("Yeni talep" formu sıfırlar).
final class SupportState extends Equatable {
  /// Varsayılan: boş form, SSS kapalı.
  const SupportState({
    this.faqQuery = '',
    this.expandedFaq,
    this.subject,
    this.message = '',
    this.attachment,
    this.errors = const {},
    this.isSubmitting = false,
    this.ticketNo,
    this.submitError,
  });

  /// SSS sorusu sayısı (`faq.q1`…`faq.q8`; `screens-profile.js:109`).
  static const int faqCount = 8;

  /// SSS sıra numaraları (1'den başlar; anahtar `SET-05.faq.<n>`).
  static final List<int> faqIndexes = [for (var i = 1; i <= faqCount; i++) i];

  /// SSS arama metni (ham girdi).
  final String faqQuery;

  /// Açık SSS sorusunun sıra numarası; aynı anda yalnızca bir soru açıktır
  /// (prototip `open === x.i`). `null` → hepsi kapalı.
  final int? expandedFaq;

  /// Seçilen konu.
  final SupportSubject? subject;

  /// Mesaj (ham girdi; en çok `Limits.supportMessageMax`, fazlası girilirken
  /// kesilir — prototip `v.slice(0, 500)`).
  final String message;

  /// Eklenen ekran görüntüsü (en çok `Limits.supportAttachmentsMax` = 1;
  /// yeniden kodlanmış JPEG — CD-135). Yoksa `null`.
  final PickedImage? attachment;

  /// Alan hataları; hatasız alanın anahtarı yoktur.
  final Map<SupportField, FormFieldError> errors;

  /// Gönderim sürüyor mu.
  final bool isSubmitting;

  /// Gönderilen talebin numarası (`GU-XXXXXX`; gösterimde `#` önekli).
  /// `null` → form görünür.
  final String? ticketNo;

  /// Son gönderimin alana bağlanamayan hatası; form değişince temizlenir.
  final SupportError? submitError;

  /// Kırpılmış mesaj (doğrulama ve yazım bununla).
  String get trimmedMessage => message.trim();

  /// Talep gönderildi mi (başarı kartı)?
  bool get isSent => ticketNo != null;

  /// Kullanıcıya gösterilen numara: `#GU-XXXXXX` (TST-23, `supportSentDesc`).
  String? get displayTicketNo => switch (ticketNo) {
    final no? => displayOf(no),
    null => null,
  };

  /// [ticketNo] numarasının gösterimi: `#GU-XXXXXX` (PLAN §9 `supportTickets`).
  static String displayOf(String ticketNo) => '$_ticketPrefix$ticketNo';

  /// Gönderilmemiş girdi var mı? Geri / sistem geri DLG-25 sorar
  /// (`UnsavedChangesMixin`).
  bool get isDirty =>
      !isSent &&
      (subject != null || trimmedMessage.isNotEmpty || attachment != null);

  /// [question] / [answer] metni arama metnine uyuyor mu? Türkçe harf
  /// katlamasıyla içerme (prototip `toLocaleLowerCase('tr')`); boş arama her
  /// soruyu gösterir.
  bool matchesFaq(String question, String answer) {
    final query = faqQuery.trLower();
    return query.isEmpty || '$question $answer'.trLower().contains(query);
  }

  @override
  List<Object?> get props => [
    faqQuery,
    expandedFaq,
    subject,
    message,
    attachment,
    errors,
    isSubmitting,
    ticketNo,
    submitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. `clear*` bayrakları ilgili alanı
  /// `null` yapar ve aynı adlı parametreden önce gelir.
  SupportState copyWith({
    String? faqQuery,
    int? expandedFaq,
    bool clearExpandedFaq = false,
    SupportSubject? subject,
    bool clearSubject = false,
    String? message,
    PickedImage? attachment,
    bool clearAttachment = false,
    Map<SupportField, FormFieldError>? errors,
    bool? isSubmitting,
    String? ticketNo,
    bool clearTicketNo = false,
    SupportError? submitError,
    bool clearSubmitError = false,
  }) => SupportState(
    faqQuery: faqQuery ?? this.faqQuery,
    expandedFaq: clearExpandedFaq ? null : expandedFaq ?? this.expandedFaq,
    subject: clearSubject ? null : subject ?? this.subject,
    message: message ?? this.message,
    attachment: clearAttachment ? null : attachment ?? this.attachment,
    errors: errors ?? this.errors,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    ticketNo: clearTicketNo ? null : ticketNo ?? this.ticketNo,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );

  static const String _ticketPrefix = '#';
}
