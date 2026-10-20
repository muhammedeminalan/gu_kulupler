import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';

/// NTF-02'de ayrı ayrı kaydedilen tercih alanları (`settings/{uid}`; her
/// biri tek alanlı `UserSettingsPatch` ile yazılır).
enum NotificationPrefField {
  /// Duyurular (`NTF-02.toggle.announcements`).
  announcements,

  /// Yeni gönderiler (`NTF-02.toggle.newPosts`; H-25, tasarım dışı).
  newPosts,

  /// Gönderiye yorumlar (`NTF-02.toggle.newComments`; H-25, tasarım dışı).
  newComments,

  /// Etkinlik hatırlatmaları (`NTF-02.toggle.eventReminders`).
  eventReminders,

  /// Yeni etkinlikler (`NTF-02.toggle.newEvents`).
  newEvents,

  /// Başvuru sonuçları (`NTF-02.toggle.applicationResults`).
  applicationResults,

  /// Yönetim bildirimleri (`NTF-02.toggle.management`; yalnızca kulüp
  /// yöneticisinde çizilir).
  management,

  /// Sistem (`NTF-02.toggle.system`).
  system,

  /// Hatırlatma zamanı (`NTF-02.reminderTime.1h` / `.1d`).
  reminderTime,

  /// Sessiz saatler açık / kapalı (`NTF-02.quiet`).
  quiet,

  /// Sessiz saat aralığı (`NTF-02.quietFrom` / `NTF-02.quietTo`, SHT-29);
  /// iki uç tek yamada yazılır.
  quietRange;

  /// Genel anahtar kartındaki tür satırları, ekran sırasıyla
  /// (`screens-events.js:112`).
  static const List<NotificationPrefField> typeToggles = [
    announcements,
    newPosts,
    newComments,
    eventReminders,
    newEvents,
    applicationResults,
    management,
    system,
  ];

  /// Kaydı yerel hatırlatıcıları etkiler mi (`LocalReminderService` yalnızca
  /// `eventReminders` + `reminderTime` okur; sessiz saat okumaz — CD-43)?
  bool get affectsReminders => this == eventReminders || this == reminderTime;

  /// Kaydı NTF-01 tercih süzgecini etkiler mi (`NotificationPreferenceFilter`)?
  bool get affectsInbox => typeToggles.contains(this);
}

/// NTF-02 "Bildirim tercihleri" durumu (PLAN §12.6
/// `NotificationPrefsViewModel`).
///
/// * [settings] ekranın gösterdiği tercihlerdir; dokunuş önce buraya yazılır
///   (iyimser), yazım reddedilirse son kaydedilen değere döner.
/// * [clubs] kulüp bazlı satırlar: kullanıcının **aktif** üyelikleri
///   (prototip `sel.myClubs`), başvuru sırasıyla.
/// * [savingKeys] yazımı süren alanlar.
final class NotificationPrefsState extends Equatable {
  /// Varsayılan: içerik yok.
  const NotificationPrefsState({
    this.settings = const UserSettingsModel(),
    this.clubs = const [],
    this.permissionGranted = false,
    this.showManagement = false,
    this.isFetching = false,
    this.isError = false,
    this.savingKeys = const {},
  });

  /// Kullanıcının tercihleri (`settings/{uid}`).
  final UserSettingsModel settings;

  /// Kulüp bazlı ayar satırları (ad + ikon).
  final List<ClubModel> clubs;

  /// Sistem bildirim izni kullanılabilir mi (`PermissionStatusX.isUsable`)?
  final bool permissionGranted;

  /// "Yönetim bildirimleri" satırı çizilir mi? Kullanıcı en az bir kulüpte
  /// aktif yönetici (`board` / `president`) ise (`screens-events.js:112`
  /// `isManager`; danışman salt okurdur).
  final bool showManagement;

  /// İlk okuma (ya da "Yeniden dene") sürüyor mu?
  final bool isFetching;

  /// Okuma başarısız mı (hata durumu + "Yeniden dene")?
  final bool isError;

  /// Yazımı süren alanlar.
  final Set<NotificationPrefField> savingKeys;

  /// İçerik çizilebilir mi (okuma bitti, hata yok)?
  bool get isLoaded => !isFetching && !isError;

  /// [field] anahtarının değeri (yalnızca açık / kapalı alanlar).
  bool isOn(NotificationPrefField field) => switch (field) {
    NotificationPrefField.announcements => settings.announcements,
    NotificationPrefField.newPosts => settings.newPosts,
    NotificationPrefField.newComments => settings.newComments,
    NotificationPrefField.eventReminders => settings.eventReminders,
    NotificationPrefField.newEvents => settings.newEvents,
    NotificationPrefField.applicationResults => settings.applicationResults,
    NotificationPrefField.management => settings.management,
    NotificationPrefField.system => settings.system,
    NotificationPrefField.quiet => settings.quiet,
    NotificationPrefField.reminderTime ||
    NotificationPrefField.quietRange => throw ArgumentError.value(
      field,
      'field',
      'açık / kapalı alan değil',
    ),
  };

  /// Sessiz saat başlangıcı; belgedeki değer okunamazsa varsayılan
  /// (`Limits.quietFromDefault`).
  TimeOfDayValue get quietFrom =>
      TimeOfDayValue.tryParse(settings.quietFrom) ??
      TimeOfDayValue.tryParse(Limits.quietFromDefault)!;

  /// Sessiz saat bitişi; belgedeki değer okunamazsa varsayılan
  /// (`Limits.quietToDefault`).
  TimeOfDayValue get quietTo =>
      TimeOfDayValue.tryParse(settings.quietTo) ??
      TimeOfDayValue.tryParse(Limits.quietToDefault)!;

  /// [clubId] kulübü sessize alınmış mı (SHT-07 "Tümünü sessize al")?
  bool isClubMuted(String clubId) => settings.clubs[clubId]?.muted ?? false;

  @override
  List<Object?> get props => [
    settings,
    clubs,
    permissionGranted,
    showManagement,
    isFetching,
    isError,
    savingKeys,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  NotificationPrefsState copyWith({
    UserSettingsModel? settings,
    List<ClubModel>? clubs,
    bool? permissionGranted,
    bool? showManagement,
    bool? isFetching,
    bool? isError,
    Set<NotificationPrefField>? savingKeys,
  }) => NotificationPrefsState(
    settings: settings ?? this.settings,
    clubs: clubs ?? this.clubs,
    permissionGranted: permissionGranted ?? this.permissionGranted,
    showManagement: showManagement ?? this.showManagement,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
    savingKeys: savingKeys ?? this.savingKeys,
  );
}
