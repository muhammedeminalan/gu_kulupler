import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

/// MGT-05 formunun adımları (prototip `f.step` 1–3; `MGT-05.next` /
/// `MGT-05.back`).
enum EventFormStep {
  /// 1 · Kapak, ad, açıklama, tür.
  basics,

  /// 2 · Başlangıç / bitiş tarih-saat, mekân, kontenjan, görünürlük,
  /// otomatik hatırlatıcı.
  schedule,

  /// 3 · Önizleme ve özet; taslak kaydet / yayınla.
  settings;

  /// Ekrandaki adım numarası (1–3; "Etkinlik oluştur · 1/3").
  int get number => index + 1;

  /// Son adım mı ("Devam" yerine "Taslak olarak kaydet" + "Yayınla").
  bool get isLast => this == EventFormStep.settings;
}

/// MGT-05 formunun hata taşıyabilen alanları (prototip `f.errors.*`).
enum EventField {
  /// Etkinlik adı (`MGT-05.title`): zorunlu, ≤ `Limits.eventTitleMax`.
  title,

  /// Açıklama (`MGT-05.desc`): ≤ `Limits.eventDescMax`.
  desc,

  /// Tür (`MGT-05.type.*`): zorunlu.
  type,

  /// Başlangıç (`MGT-05.startDate` / `.startTime`): zorunlu; yayında
  /// gelecekte; başlamış yayındaki etkinlikte kilitli (W-82).
  startsAt,

  /// Bitiş (`MGT-05.endDate` / `.endTime`): zorunlu; başlangıçtan sonra
  /// (`endBeforeStart`).
  endsAt,

  /// Mekân (`MGT-05.place` → SHT-30): zorunlu.
  place,

  /// Kontenjan (`MGT-05.capacity.*`): ≥ 1; düzenlemede ≥ `goingCount`
  /// (`capacityBelowGoing`).
  capacity;

  /// Alanın bulunduğu adım (doğrulama hatasında o adıma dönülür).
  EventFormStep get step => switch (this) {
    EventField.title ||
    EventField.desc ||
    EventField.type => EventFormStep.basics,
    EventField.startsAt ||
    EventField.endsAt ||
    EventField.place ||
    EventField.capacity => EventFormStep.schedule,
  };
}

/// `EventFormViewModel` yazım sonucu.
enum EventFormOutcome {
  /// Çağrı yok sayıldı (süren gönderim, yüklenmemiş form, oturum yok).
  ignored,

  /// Form geçersiz; alan hataları state'e yazıldı, ilk hatalı adıma dönüldü.
  invalid,

  /// Yazılamaz: danışman (TST-26) ya da çevrimdışı (TST-24).
  blocked,

  /// DLG-22'de "Düzenlemeye dön" seçildi.
  cancelled,

  /// Yazım ya da kapak yüklemesi başarısız (toast / hata bandı gösterildi).
  failed,

  /// İçerik kaydedildi (taslak — TST-13; yayındaki etkinlik — TST-21).
  saved,

  /// Kaydedildi ve yayınlandı (TST-30).
  published,

  /// Kaydedildi ve yayından çekildi (TST-X19, K-F).
  unpublished,
}

/// MGT-05 "Etkinlik oluştur" / "Etkinliği düzenle" ekranının durumu (PLAN
/// §12.6 `EventFormViewModel`; prototip `S['MGT-05']`,
/// `screens-manage.js:87–116`).
///
/// Zamanlar UTC'dir (D-26); ekranda Istanbul duvar saatiyle gösterilir.
/// Kontenjan iki alanla tutulur: [capacity] adımlayıcının değeri,
/// [isUnlimited] "Sınırsız" anahtarı (prototip `f.capacity` / `f.unlimited`)
/// — anahtar kapanınca önceki değer geri gelir.
final class EventFormState extends Equatable {
  /// Varsayılanlar prototip `init()` ile aynıdır (`screens-manage.js:89`);
  /// başlangıç / bitiş ViewModel'in `build`'inde kurulur.
  const EventFormState({
    this.step = EventFormStep.basics,
    this.original,
    this.club,
    this.clubEvents = const [],
    this.title = '',
    this.desc = '',
    this.type = EventType.social,
    this.startsAt,
    this.endsAt,
    this.placeId,
    this.placeText = '',
    this.capacity = defaultCapacity,
    this.isUnlimited = false,
    this.visibility = EventVisibility.public,
    this.autoReminder = true,
    this.coverPalette = ClubPalette.red,
    this.coverPattern = ClubPattern.mountain,
    this.coverPath,
    this.pendingCover,
    this.timeLocked = false,
    this.errors = const {},
    this.isDirty = false,
    this.isLoading = false,
    this.isError = false,
    this.isSubmitting = false,
    this.isCoverUploading = false,
    this.isSubmitError = false,
  });

  /// Yeni etkinliğin kontenjanı (prototip `capacity: 40`).
  static const int defaultCapacity = 40;

  /// Adımlayıcının adımı (`f.capacity ∓ 5`).
  static const int capacityStep = 5;

  /// Adımlayıcının üst sınırı (`Math.min(1000, …)`).
  static const int capacityMax = 1000;

  /// Yeni etkinliğin varsayılan başlangıcı bugünden bu kadar gün sonra
  /// (prototip `GU.at(7, 18, 0)`).
  static const int defaultLeadDays = 7;

  /// Varsayılan başlangıç saati (Istanbul, 18:00).
  static const int defaultStartHour = 18;

  /// Varsayılan süre, saat (`+ 2 * 36e5`).
  static const int defaultDurationHours = 2;

  /// Varsayılan süre; başlangıç bitişi geçince bitiş başlangıç + bu süreye
  /// çekilir.
  static const Duration defaultDuration = Duration(
    hours: defaultDurationHours,
  );

  /// Gösterilen adım.
  final EventFormStep step;

  /// Belgedeki etkinlik: düzenlemede okunan, yeni etkinlikte ilk taslak
  /// yazımından (`createDraft`) dönen model; henüz yazılmamışsa `null`.
  /// Kapak yüklemesinin ön koşulu belge kimliğidir (CD-47, K-18).
  final EventModel? original;

  /// Kulüp (kapak paleti / sembolü, DLG-22 üye sayısı); okunmadıysa `null`.
  final ClubModel? club;

  /// Kulübün etkinlikleri (taslaklar dahil; çakışma bandı — prototip
  /// `conflicts`).
  final List<EventModel> clubEvents;

  /// Ad (≤ `Limits.eventTitleMax`; ViewModel keser).
  final String title;

  /// Açıklama (≤ `Limits.eventDescMax`).
  final String desc;

  /// Tür (`MGT-05.type.*`).
  final EventType? type;

  /// Başlangıç (UTC).
  final DateTime? startsAt;

  /// Bitiş (UTC).
  final DateTime? endsAt;

  /// Mekân tablosu kimliği (SHT-30); serbest metinde `null`.
  final String? placeId;

  /// Serbest metin mekân (SHT-30 "Başka bir yer yaz"); tablodan seçimde boş.
  final String placeText;

  /// Adımlayıcının değeri (≥ 1); [isUnlimited] iken yazılmaz.
  final int capacity;

  /// "Sınırsız" (`MGT-05.unlimited`): kontenjan `null` yazılır.
  final bool isUnlimited;

  /// Görünürlük (`MGT-05.visibility.*`).
  final EventVisibility visibility;

  /// Otomatik hatırlatıcı (`MGT-05.autoReminder`).
  final bool autoReminder;

  /// Şablon kapak paleti (SHT-31).
  final ClubPalette coverPalette;

  /// Şablon kapak deseni (SHT-31).
  final ClubPattern coverPattern;

  /// Yüklenmiş özel kapağın Storage yolu (`events/{eventId}/{file}`).
  final String? coverPath;

  /// Seçilmiş, henüz yüklenmemiş özel kapak (SHT-31 "Galeriden seç");
  /// kaydetme / yayın anında belge kimliğinden sonra yüklenir (CD-47).
  final PickedImage? pendingCover;

  /// Başlangıç / bitiş kilitli mi: yayındaki etkinlik başlamış (W-82).
  final bool timeLocked;

  /// Alan hataları.
  final Map<EventField, FormFieldError> errors;

  /// Kaydedilmemiş değişiklik var mı (DLG-25)?
  final bool isDirty;

  /// Düzenlenecek etkinlik okunuyor.
  final bool isLoading;

  /// Düzenlenecek etkinlik okunamadı / düzenlenemez (iptal, başka kulüp).
  final bool isError;

  /// Yazım sürüyor (düğmeler döner, form kilitli).
  final bool isSubmitting;

  /// Özel kapak yükleniyor.
  final bool isCoverUploading;

  /// Son yazım alana bağlanamayan bir hatayla bitti (hata bandı).
  final bool isSubmitError;

  /// Belge kimliği; henüz yazılmamışsa `null`.
  String? get eventId => original?.id;

  /// Belgedeki etkinlik yayında mı ("Yayınla" yerine "Kaydet").
  bool get isPublished => original?.status == EventStatus.published;

  /// Kayıtlı sayısı (düzenlemede "Şu an {n} kayıtlı").
  int get goingCount => original?.goingCount ?? 0;

  /// Kontenjanın alt sınırı: kayıtlı sayısının altına inemez.
  int get minCapacity => math.max(1, goingCount);

  /// Yazılacak kontenjan; `null` = sınırsız.
  int? get capacityValue => isUnlimited ? null : capacity;

  /// Yayındaki etkinlik taslağa alınabilir mi (K-F: kayıtlı yokken).
  bool get canUnpublish => !isPublished || goingCount == 0;

  /// Aynı zaman aralığına düşen yayındaki diğer etkinlik sayısı (prototip
  /// `conflicts`).
  int get conflictCount {
    final start = startsAt;
    final end = endsAt;
    if (start == null || end == null) return 0;
    return clubEvents
        .where(
          (e) =>
              e.id != eventId &&
              e.status == EventStatus.published &&
              e.startsAt.isBefore(end) &&
              e.endsAt.isAfter(start),
        )
        .length;
  }

  @override
  List<Object?> get props => [
    step,
    original,
    club,
    clubEvents,
    title,
    desc,
    type,
    startsAt,
    endsAt,
    placeId,
    placeText,
    capacity,
    isUnlimited,
    visibility,
    autoReminder,
    coverPalette,
    coverPattern,
    coverPath,
    pendingCover,
    timeLocked,
    errors,
    isDirty,
    isLoading,
    isError,
    isSubmitting,
    isCoverUploading,
    isSubmitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. `clear…` bayrakları null olabilen
  /// alanı boşaltır.
  EventFormState copyWith({
    EventFormStep? step,
    EventModel? original,
    ClubModel? club,
    List<EventModel>? clubEvents,
    String? title,
    String? desc,
    EventType? type,
    DateTime? startsAt,
    DateTime? endsAt,
    String? placeId,
    bool clearPlaceId = false,
    String? placeText,
    int? capacity,
    bool? isUnlimited,
    EventVisibility? visibility,
    bool? autoReminder,
    ClubPalette? coverPalette,
    ClubPattern? coverPattern,
    String? coverPath,
    bool clearCoverPath = false,
    PickedImage? pendingCover,
    bool clearPendingCover = false,
    bool? timeLocked,
    Map<EventField, FormFieldError>? errors,
    bool? isDirty,
    bool? isLoading,
    bool? isError,
    bool? isSubmitting,
    bool? isCoverUploading,
    bool? isSubmitError,
  }) => EventFormState(
    step: step ?? this.step,
    original: original ?? this.original,
    club: club ?? this.club,
    clubEvents: clubEvents ?? this.clubEvents,
    title: title ?? this.title,
    desc: desc ?? this.desc,
    type: type ?? this.type,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    placeId: clearPlaceId ? null : placeId ?? this.placeId,
    placeText: placeText ?? this.placeText,
    capacity: capacity ?? this.capacity,
    isUnlimited: isUnlimited ?? this.isUnlimited,
    visibility: visibility ?? this.visibility,
    autoReminder: autoReminder ?? this.autoReminder,
    coverPalette: coverPalette ?? this.coverPalette,
    coverPattern: coverPattern ?? this.coverPattern,
    coverPath: clearCoverPath ? null : coverPath ?? this.coverPath,
    pendingCover: clearPendingCover ? null : pendingCover ?? this.pendingCover,
    timeLocked: timeLocked ?? this.timeLocked,
    errors: errors ?? this.errors,
    isDirty: isDirty ?? this.isDirty,
    isLoading: isLoading ?? this.isLoading,
    isError: isError ?? this.isError,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isCoverUploading: isCoverUploading ?? this.isCoverUploading,
    isSubmitError: isSubmitError ?? this.isSubmitError,
  );
}
