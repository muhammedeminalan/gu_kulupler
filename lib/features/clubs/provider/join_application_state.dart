import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

// `JoinApplicationOutcome` SHT-05'i açan her ekranla ortaktır (CLB-02 arama
// `features/search` altındadır — `ClubJoinMixin` dosyası); bu dosyayı içe
// aktaranlar aynı adı görmeye devam eder.
export 'package:gu_kulupler/product/mixin/club_join_mixin.dart'
    show JoinApplicationOutcome;

/// SHT-05 formunun alanları.
enum JoinApplicationField {
  /// "Neden katılmak istiyorsun?" notu.
  note,
}

/// SHT-05 "Katılma başvurusu" formunun durumu.
final class JoinApplicationState extends Equatable {
  /// Varsayılan: kulüp yok, not boş.
  const JoinApplicationState({
    this.club,
    this.membership,
    this.note = '',
    this.errors = const {},
    this.isFetching = false,
    this.isError = false,
    this.isSubmitting = false,
    this.submitError,
  });

  /// Başvurulan kulüp; yüklenene kadar `null`.
  final ClubModel? club;

  /// Kullanıcının bu kulüpteki üyelik belgesi (oturumdan, canlı); yoksa
  /// `null`.
  final MembershipModel? membership;

  /// Yazılan not (ham; gönderimde kırpılır). En çok
  /// `Limits.applicationNoteMax`.
  final String note;

  /// Gönderimde bulunan alan hataları.
  final Map<JoinApplicationField, FormFieldError> errors;

  /// Kulüp okunuyor mu?
  final bool isFetching;

  /// Kulüp okunamadı mı (silinmiş kulüp dahil)?
  final bool isError;

  /// Başvuru gönderiliyor mu?
  final bool isSubmitting;

  /// Son gönderimin sunucu hatası; yoksa `null`.
  final SubmitError? submitError;

  /// Form kirli mi (prototip `dirty=${!!note}`)? Kirliyken kapanış DLG-25
  /// sorar.
  bool get isDirty => note.isNotEmpty;

  /// Not zorunlu mu? Kulüp not istiyorsa ve başvuru yönetici onayına
  /// gidiyorsa `true`; anında katılımda ([isInstant]) not yazılmaz, kulüp
  /// yüklenmediyse `false`.
  bool get requireNote => (club?.requireNote ?? false) && !isInstant;

  /// Gönderim anında katılım mı olacak? Yalnızca onay istemeyen kulüpte ve
  /// eski kaydı ([reviewStatuses]) olmayan kullanıcı için `true`; diğer her
  /// durumda başvuru yönetici onayına gider.
  bool get isInstant =>
      !(club?.approvalRequired ?? true) &&
      !reviewStatuses.contains(membership?.status);

  /// Onaysız kulüpte de yönetici onayına giden önceki durumlar (rules-spec
  /// §3.4 M4; CD-137 madde 8s).
  static const Set<MembershipStatus> reviewStatuses = {
    MembershipStatus.rejected,
    MembershipStatus.removed,
    MembershipStatus.cancelled,
  };

  /// Yeniden başvuru için beklenen an (`memberships.retryAfter`); yoksa
  /// `null`.
  DateTime? get retryAfter => membership?.retryAfter;

  /// [now] anında yeniden başvuru bekleme süresi sürüyor mu?
  bool isWaiting(DateTime now) => retryAfter?.isAfter(now) ?? false;

  @override
  List<Object?> get props => [
    club,
    membership,
    note,
    errors,
    isFetching,
    isError,
    isSubmitting,
    submitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearMembership] ve
  /// [clearSubmitError] ilgili alanı `null` yapar ve aynı adlı parametreden
  /// önce gelir.
  JoinApplicationState copyWith({
    ClubModel? club,
    MembershipModel? membership,
    bool clearMembership = false,
    String? note,
    Map<JoinApplicationField, FormFieldError>? errors,
    bool? isFetching,
    bool? isError,
    bool? isSubmitting,
    SubmitError? submitError,
    bool clearSubmitError = false,
  }) => JoinApplicationState(
    club: club ?? this.club,
    membership: clearMembership ? null : membership ?? this.membership,
    note: note ?? this.note,
    errors: errors ?? this.errors,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );
}
