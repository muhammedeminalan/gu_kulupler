import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

/// CLB-05 not formunun alanları.
enum ApplicationField {
  /// "Notun" — başvuru notu.
  note,
}

/// Başvurunun ekrandaki evresi (prototip `st`, `screens-clubs.js:127`):
/// CLB-05'in rozeti, zaman çizelgesi ve gövdesi buna göre kurulur.
enum ApplicationPhase {
  /// Karar bekliyor (`pending`): not düzenlenir, istek iptal edilebilir.
  pending,

  /// Onaylandı, kullanıcı üye (`active`).
  approved,

  /// Reddedildi (`rejected`): neden + yeniden başvuru tarihi.
  rejected,

  /// Üyelikten çıkarıldı (`removed`): neden + yeniden başvuru tarihi.
  removed,

  /// Aktif başvuru yok (prototip `none`): üyelik belgesi yok, istek iptal
  /// edilmiş (`cancelled`) ya da kullanıcı kulüpten ayrılmış (`left`).
  none;

  /// Üyelik durumunun evresi; belge yoksa ([status] `null`) [none].
  static ApplicationPhase of(MembershipStatus? status) => switch (status) {
    MembershipStatus.pending => pending,
    MembershipStatus.active => approved,
    MembershipStatus.rejected => rejected,
    MembershipStatus.removed => removed,
    MembershipStatus.cancelled || MembershipStatus.left || null => none,
  };
}

/// `ClubApplicationViewModel.reapply` sonucu ("Tekrar başvur" / "Katıl").
enum ReapplyOutcome {
  /// Başvuru formu açılmalı (SHT-05): kulüp onay istiyor ya da kullanıcının
  /// eski kaydı yönetici onayına gidiyor. Sayfayı view açar.
  openSheet,

  /// Onaysız kulübe anında katılındı (TST-34 gösterildi).
  joined,

  /// Başvurulamaz: kulüp başvuru almıyor (TST-X1) ya da bekleme süresi
  /// dolmadı (TST-X4).
  blocked,

  /// Katılım yazılamadı (çevrimdışı, ağ, yetki, diğer) ya da çağrı yok
  /// sayıldı (kulüp yüklenmedi, süren işlem var).
  failed,
}

/// CLB-04 "İsteğin iletildi" ve CLB-05 "Başvuru durumu" ekranlarının ortak
/// durumu (PLAN §12.6).
final class ClubApplicationState extends Equatable {
  /// Varsayılan: kulüp ve üyelik yok, not boş.
  const ClubApplicationState({
    this.club,
    this.membership,
    this.note = '',
    this.savedNote = '',
    this.errors = const {},
    this.submitError,
    this.showNotificationPrompt = false,
    this.isFetching = false,
    this.isError = false,
    this.isNotFound = false,
    this.isSaving = false,
    this.isCancelling = false,
    this.isJoining = false,
  });

  /// Başvurulan kulüp; yüklenene kadar `null`.
  final ClubModel? club;

  /// Kullanıcının bu kulüpteki üyelik belgesi (oturumdan, canlı —
  /// `SessionState.memberships`); yoksa `null`.
  final MembershipModel? membership;

  /// Not alanındaki metin (ham; kaydederken kırpılır).
  final String note;

  /// Sunucudaki not (`memberships/{id}/private/contact.note` — CD-137).
  /// CLB-04 kartındaki alıntı ve "Kaydet"in açık olup olmadığı bundan gelir.
  final String savedNote;

  /// Not alanının doğrulama hataları.
  final Map<ApplicationField, FormFieldError> errors;

  /// Son yazımın (not kaydı, iptal, katılım) alana bağlanamayan hatası;
  /// yoksa `null`. Ağ hatası toast ile bildirilir (TST-24), buraya yazılmaz.
  final SubmitError? submitError;

  /// CLB-04 "Sonucu kaçırma — bildirimleri aç." kartı gösterilsin mi
  /// (bildirim izni verilmemiş)? İzin durumu okunana kadar `false`.
  final bool showNotificationPrompt;

  /// Kulüp ve not okunuyor mu (iskelet)?
  final bool isFetching;

  /// Kulüp ya da not okunamadı mı?
  final bool isError;

  /// Kulüp yok / silinmiş mi (→ SYS-04)?
  final bool isNotFound;

  /// Not kaydediliyor mu ("Kaydet" meşgul)?
  final bool isSaving;

  /// İstek iptal ediliyor mu ("İsteği iptal et" meşgul)?
  final bool isCancelling;

  /// Onaysız kulübe katılım yazılıyor mu ("Katıl" meşgul)?
  final bool isJoining;

  /// Başvurunun evresi ([membership] durumundan).
  ApplicationPhase get phase => ApplicationPhase.of(membership?.status);

  /// Not sunucudakinden farklı mı? Baştaki / sondaki boşluk fark sayılmaz
  /// (kaydederken kırpılır).
  bool get isDirty => note.trim() != savedNote.trim();

  /// Not sınırı aşıyor mu (`Limits.applicationNoteMax`)? Alanın sayacı
  /// kırmızıya döner, "Kaydet" kapanır.
  bool get isNoteTooLong => note.trim().length > Limits.applicationNoteMax;

  /// "Kaydet" açık mı: başvuru bekliyor, not değişmiş ve sınırın içinde.
  bool get canSaveNote =>
      phase == ApplicationPhase.pending && isDirty && !isNoteTooLong;

  /// Süren bir yazım var mı (not kaydı, iptal, katılım)?
  bool get isBusy => isSaving || isCancelling || isJoining;

  /// Yeniden başvurunun açılacağı an (`memberships.retryAfter`); yoksa
  /// `null`.
  DateTime? get retryAfter => membership?.retryAfter;

  /// [now] anında yeniden başvurulabilir mi (prototip `canReapply`,
  /// `actions.js:65`): üyelik ya da bekleme anı yoksa ya da an geldiyse.
  bool canReapplyAt(DateTime now) {
    final until = retryAfter;
    return until == null || !until.isAfter(now);
  }

  /// [now] anında yeniden başvuruya kalan süre; bekleme yoksa ya da dolduysa
  /// `null`.
  Duration? remainingUntilRetry(DateTime now) {
    final until = retryAfter;
    if (until == null || !until.isAfter(now)) return null;
    return until.difference(now);
  }

  @override
  List<Object?> get props => [
    club,
    membership,
    note,
    savedNote,
    errors,
    submitError,
    showNotificationPrompt,
    isFetching,
    isError,
    isNotFound,
    isSaving,
    isCancelling,
    isJoining,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearMembership] ve
  /// [clearSubmitError] ilgili alanı `null` yapar ve aynı adlı parametreden
  /// önce gelir.
  ClubApplicationState copyWith({
    ClubModel? club,
    MembershipModel? membership,
    bool clearMembership = false,
    String? note,
    String? savedNote,
    Map<ApplicationField, FormFieldError>? errors,
    SubmitError? submitError,
    bool clearSubmitError = false,
    bool? showNotificationPrompt,
    bool? isFetching,
    bool? isError,
    bool? isNotFound,
    bool? isSaving,
    bool? isCancelling,
    bool? isJoining,
  }) => ClubApplicationState(
    club: club ?? this.club,
    membership: clearMembership ? null : membership ?? this.membership,
    note: note ?? this.note,
    savedNote: savedNote ?? this.savedNote,
    errors: errors ?? this.errors,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
    showNotificationPrompt:
        showNotificationPrompt ?? this.showNotificationPrompt,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
    isNotFound: isNotFound ?? this.isNotFound,
    isSaving: isSaving ?? this.isSaving,
    isCancelling: isCancelling ?? this.isCancelling,
    isJoining: isJoining ?? this.isJoining,
  );
}
