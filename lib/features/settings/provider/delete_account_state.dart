import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;

/// SET-03 adımları — prototip `f.step` 1…3 (`screens-profile.js:81–91`).
///
/// Tasarımda başkanlık ön koşulu 1. adımın içindedir (uyarı kartının altında
/// "Önce başkanlığı devretmelisin" kartı; "Devam" kapalı); 2. adım ayrılma
/// nedenidir (isteğe bağlı). PLAN §12.6'daki `precondition` adı tasarıma göre
/// [reason] olarak uygulanır (CD-152).
enum DeleteStep {
  /// 1/3 — uyarı: silinecekler / kalacaklar + başkanlık engeli.
  warning,

  /// 2/3 — "Neden ayrılıyorsun?" (isteğe bağlı; saklanmaz — CD-152).
  reason,

  /// 3/3 — şifre + "SİL" yazma → kalıcı silme.
  confirm;

  /// Ekrandaki sıra numarası (1…3).
  int get number => index + 1;
}

/// 2. adımın seçenekleri — prototip `reasons` (`screens-profile.js:83`).
enum DeleteReason {
  /// "Uygulamayı kullanmıyorum" (`SET-03.reason.noUse`).
  noUse,

  /// "Çok fazla bildirim" (`SET-03.reason.tooMany`).
  tooMany,

  /// "Gizlilik endişeleri" (`SET-03.reason.privacy`).
  privacy,

  /// "Mezun oldum" (`SET-03.reason.graduated`).
  graduated,

  /// "Diğer" (`SET-03.reason.other`).
  other,
}

/// Silmenin sunucu / kimlik kaynaklı başarısızlığı (PLAN §12.6
/// `DeleteError`).
enum DeleteError {
  /// Şifre hatalı (`AuthError.invalidCredentials`) — şifre alanının altında
  /// "Şifre hatalı" (prototip `auth.err.wrongPassword`).
  wrongPassword,

  /// Onaydan hemen önceki ön denetimde başkanlık bulundu (TST-X10; 1. adıma
  /// dönülür).
  isPresident,

  /// Çok fazla deneme — form altı hata satırı.
  tooManyRequests,

  /// Ağ yok (TST-24). Hiçbir şey yazılmamıştır; yeniden denenebilir.
  network,

  /// Diğer her hata — form altı hata satırı; yeniden denenebilir.
  unknown,
}

/// `DeleteAccountViewModel.confirm` sonucu.
enum DeleteOutcome {
  /// Gönderim süreceği için ya da form eksik (TST-X11) yok sayıldı.
  ignored,

  /// Kimlik doğrulanamadı / ön denetim ya da `markDeleted` düştü — hiçbir
  /// şey yazılmadı ([DeleteAccountState.submitError]).
  failed,

  /// Başkanlık engeli (TST-X10) — 1. adıma dönüldü.
  blockedByPresidency,

  /// Hesap silindi; oturum kapandı (TST-22 → AUT-01).
  deleted,
}

/// SET-03 Hesabı sil ekranının durumu (PLAN §12.6).
final class DeleteAccountState extends Equatable {
  /// 1. adım, ön denetim henüz yapılmamış.
  const DeleteAccountState({
    this.step = DeleteStep.warning,
    this.isChecking = true,
    this.isCheckError = false,
    this.presidentOfClubIds = const [],
    this.clubNames = const <String, String>{},
    this.reason,
    this.reasonText = '',
    this.password = '',
    this.confirmWord = '',
    this.isSubmitting = false,
    this.progress,
    this.submitError,
  });

  /// "Eklemek istediğin bir şey var mı?" alanının en çok uzunluğu (prototip
  /// `maxLength=${300}`, `screens-profile.js:88`). Neden saklanmaz; sınır
  /// yalnızca arayüzdedir.
  static const int reasonTextMax = 300;

  /// Etkin adım.
  final DeleteStep step;

  /// Başkanlık ön denetimi sürüyor mu (`AccountDeletionRepository.precheck`)?
  final bool isChecking;

  /// Ön denetim okunamadı mı? "Devam" yeniden dener.
  final bool isCheckError;

  /// Kullanıcının etkin başkanı olduğu kulüpler (TST-X10; kimlik sırasıyla).
  final List<String> presidentOfClubIds;

  /// [presidentOfClubIds] kulüplerinin adları; okunamayan kulüp yoktur
  /// (arayüz kimliği gösterir).
  final Map<String, String> clubNames;

  /// 2. adımda seçilen neden (isteğe bağlı).
  final DeleteReason? reason;

  /// 2. adımın serbest metni (≤ [reasonTextMax]).
  final String reasonText;

  /// 3. adım — mevcut şifre (yeniden doğrulama).
  final String password;

  /// 3. adım — onay sözcüğü girdisi ("SİL").
  final String confirmWord;

  /// Silme sürüyor mu (yeniden doğrulama → dizi → oturum kapatma)?
  final bool isSubmitting;

  /// Temizlik dizisinin ilerlemesi (`markDeleted` kesinleştikten sonra);
  /// `null` → dizi başlamadı.
  final DeleteProgress? progress;

  /// Son gönderimin hatası; şifre / onay girdisi değişince temizlenir.
  final DeleteError? submitError;

  /// Başkanlık engeli var mı (1. adımda "Devam" kapalı)?
  bool get isPresident => presidentOfClubIds.isNotEmpty;

  /// [expectedWord] ile (ARB `set03ConfirmWord`) onaylanabilir mi: şifre
  /// dolu ve girdi kırpılıp Türkçe büyük harfe çevrildiğinde **tam** eşleşiyor
  /// (prototip `f.confirm.trim().toLocaleUpperCase('tr') !== 'SİL'`).
  bool canConfirm(String expectedWord) =>
      password.isNotEmpty && confirmWord.trim().trUpper() == expectedWord;

  @override
  List<Object?> get props => [
    step,
    isChecking,
    isCheckError,
    presidentOfClubIds,
    clubNames,
    reason,
    reasonText,
    password,
    confirmWord,
    isSubmitting,
    progress,
    submitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearSubmitError] hatayı,
  /// [clearProgress] ilerlemeyi siler; ikisi de karşılık gelen değerden önce
  /// gelir.
  DeleteAccountState copyWith({
    DeleteStep? step,
    bool? isChecking,
    bool? isCheckError,
    List<String>? presidentOfClubIds,
    Map<String, String>? clubNames,
    DeleteReason? reason,
    String? reasonText,
    String? password,
    String? confirmWord,
    bool? isSubmitting,
    DeleteProgress? progress,
    bool clearProgress = false,
    DeleteError? submitError,
    bool clearSubmitError = false,
  }) => DeleteAccountState(
    step: step ?? this.step,
    isChecking: isChecking ?? this.isChecking,
    isCheckError: isCheckError ?? this.isCheckError,
    presidentOfClubIds: presidentOfClubIds ?? this.presidentOfClubIds,
    clubNames: clubNames ?? this.clubNames,
    reason: reason ?? this.reason,
    reasonText: reasonText ?? this.reasonText,
    password: password ?? this.password,
    confirmWord: confirmWord ?? this.confirmWord,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    progress: clearProgress ? null : progress ?? this.progress,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );
}
