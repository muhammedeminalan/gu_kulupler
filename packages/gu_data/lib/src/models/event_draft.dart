import 'package:equatable/equatable.dart';
import 'package:gu_data/src/models/enums/club_palette.dart';
import 'package:gu_data/src/models/enums/club_pattern.dart';
import 'package:gu_data/src/models/enums/event_type.dart';
import 'package:gu_data/src/models/enums/event_visibility.dart';

/// Henüz yazılmamış etkinlik (PLAN §10.4 `EventRepository.create` /
/// `createDraft`; MGT-05 formu).
///
/// Yalnızca yöneticinin girdiği alanları taşır; kimlik, kulüp, oluşturan,
/// durum, sayaçlar, kapak tohumu (`FirestoreIds.eventCoverSeed`) ve zaman
/// alanları yazım anında repository tarafından kurulur. Özel kapak görseli
/// (`coverPath`) taslakta **yoktur**: etkinlik önce oluşturulur, kapak
/// `EventRepository.uploadCover` ile sonradan yüklenir (CD-47).
///
/// Alan kuralları (`FieldValidators.eventTitle / eventDesc / placeId /
/// placeText / capacity / eventEnd`): [title] 1 – `Limits.eventTitleMax`,
/// [desc] ≤ `Limits.eventDescMax`, [endsAt] > [startsAt], [capacity] `null`
/// (sınırsız) ya da ≥ 1, [placeId] `StaticTables.placeIds` içinde, [placeText]
/// ≤ `Limits.placeTextMax`. Zamanlar UTC'dir (D-26).
final class EventDraft extends Equatable {
  /// [type] türünde, [startsAt] – [endsAt] arasında etkinlik taslağı.
  const EventDraft({
    required this.title,
    required this.type,
    required this.startsAt,
    required this.endsAt,
    required this.coverPalette,
    required this.coverPattern,
    this.desc = '',
    this.placeId,
    this.placeText,
    this.capacity,
    this.visibility = EventVisibility.public,
    this.registrationOpen = true,
    this.autoReminder = true,
  });

  /// Başlık (1 – `Limits.eventTitleMax`).
  final String title;

  /// Açıklama (≤ `Limits.eventDescMax`).
  final String desc;

  /// Etkinlik türü.
  final EventType type;

  /// Başlangıç anı (UTC).
  final DateTime startsAt;

  /// Bitiş anı (UTC); [startsAt]'ten sonradır.
  final DateTime endsAt;

  /// Mekân tablosu kimliği (`StaticTables.placeIds`); serbest metin mekânda
  /// `null`.
  final String? placeId;

  /// Serbest metin mekân (≤ `Limits.placeTextMax`).
  final String? placeText;

  /// Kontenjan; `null` = sınırsız, doluysa ≥ 1.
  final int? capacity;

  /// Görünürlük (herkese açık ya da yalnızca üyeler).
  final EventVisibility visibility;

  /// Kayıt açık mı?
  final bool registrationOpen;

  /// Otomatik hatırlatma açık mı?
  final bool autoReminder;

  /// Şablon kapağın paleti (SHT-31).
  final ClubPalette coverPalette;

  /// Şablon kapağın deseni (SHT-31).
  final ClubPattern coverPattern;

  @override
  List<Object?> get props => [
    title,
    desc,
    type,
    startsAt,
    endsAt,
    placeId,
    placeText,
    capacity,
    visibility,
    registrationOpen,
    autoReminder,
    coverPalette,
    coverPattern,
  ];
}

/// Var olan etkinlikte yöneticinin değiştirebildiği içerik alanlarının yaması
/// (PLAN §10.4 `EventRepository.update`; rules-spec §3.7 U).
///
/// Yalnızca **verilen** alanlar yazılır; verilmeyen alan belgede olduğu gibi
/// kalır. Null olabilen bir alanı boşaltmak için ilgili `clear…` bayrağı
/// verilir (belgeye açık `null` yazılır); aynı alan için hem değer hem bayrak
/// verilemez (`FirestoreError.invalidArgument`).
///
/// Durum (`status`), iptal nedeni, yayın anı, sayaçlar, kulüp ve oluşturan bu
/// yamayla **değiştirilemez** (tipte yoktur; Rules da reddeder) — durum
/// geçişleri `publish` / `unpublish` / `cancel` iledir. [coverPath] yalnızca
/// etkinliğin kendi klasöründeki bir yol olabilir
/// (`StoragePaths.isEventCover`, CD-47); olağan akışta onu
/// `EventRepository.uploadCover` yazar.
final class EventEditPatch extends Equatable {
  /// Verilen alanları taşıyan yama.
  const EventEditPatch({
    this.title,
    this.desc,
    this.type,
    this.startsAt,
    this.endsAt,
    this.placeId,
    this.placeText,
    this.capacity,
    this.visibility,
    this.registrationOpen,
    this.autoReminder,
    this.coverPalette,
    this.coverPattern,
    this.coverPath,
    this.clearPlaceId = false,
    this.clearPlaceText = false,
    this.clearCapacity = false,
    this.clearCoverPath = false,
  });

  /// Yeni başlık (1 – `Limits.eventTitleMax`).
  final String? title;

  /// Yeni açıklama (≤ `Limits.eventDescMax`; boş dizge açıklamayı kaldırır).
  final String? desc;

  /// Yeni tür.
  final EventType? type;

  /// Yeni başlangıç anı (UTC).
  final DateTime? startsAt;

  /// Yeni bitiş anı (UTC); yazım-sonrası başlangıçtan sonra olmalıdır.
  final DateTime? endsAt;

  /// Yeni mekân tablosu kimliği.
  final String? placeId;

  /// Yeni serbest metin mekân (≤ `Limits.placeTextMax`).
  final String? placeText;

  /// Yeni kontenjan (≥ 1); yayındaki etkinlikte kayıtlı sayısından
  /// (`goingCount`) küçük olamaz.
  final int? capacity;

  /// Yeni görünürlük.
  final EventVisibility? visibility;

  /// Kayıt açık mı?
  final bool? registrationOpen;

  /// Otomatik hatırlatma açık mı?
  final bool? autoReminder;

  /// Yeni şablon paleti.
  final ClubPalette? coverPalette;

  /// Yeni şablon deseni.
  final ClubPattern? coverPattern;

  /// Yeni özel kapak yolu (`events/{eventId}/{file}`).
  final String? coverPath;

  /// Mekân tablosu kimliğini boşalt.
  final bool clearPlaceId;

  /// Serbest metin mekânı boşalt.
  final bool clearPlaceText;

  /// Kontenjanı kaldır (sınırsız).
  final bool clearCapacity;

  /// Özel kapağı kaldır (şablon kapağa dön; dosya silinmez — D-10).
  final bool clearCoverPath;

  /// Yama hiçbir alan taşımıyor mu?
  bool get isEmpty =>
      title == null &&
      desc == null &&
      type == null &&
      startsAt == null &&
      endsAt == null &&
      placeId == null &&
      placeText == null &&
      capacity == null &&
      visibility == null &&
      registrationOpen == null &&
      autoReminder == null &&
      coverPalette == null &&
      coverPattern == null &&
      coverPath == null &&
      !clearPlaceId &&
      !clearPlaceText &&
      !clearCapacity &&
      !clearCoverPath;

  @override
  List<Object?> get props => [
    title,
    desc,
    type,
    startsAt,
    endsAt,
    placeId,
    placeText,
    capacity,
    visibility,
    registrationOpen,
    autoReminder,
    coverPalette,
    coverPattern,
    coverPath,
    clearPlaceId,
    clearPlaceText,
    clearCapacity,
    clearCoverPath,
  ];
}
