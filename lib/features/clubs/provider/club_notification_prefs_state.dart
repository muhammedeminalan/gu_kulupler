import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// SHT-07'deki dört anahtar (`sheets.js:38`; `SHT-07.toggle.<ad>`).
enum ClubPrefKey {
  /// Duyurular.
  announcements,

  /// Yeni etkinlikler.
  events,

  /// Yeni gönderiler.
  posts,

  /// Tümünü sessize al.
  muted,
}

/// SHT-07 "Kulüp bildirimleri" durumu — tek kulübün bildirim tercihleri.
final class ClubNotificationPrefsState extends Equatable {
  /// Varsayılan: tercihler açık, henüz yüklenmedi.
  const ClubNotificationPrefsState({
    this.prefs = const ClubNotificationPrefsModel(),
    this.isLoaded = false,
    this.isSaving = false,
    this.isError = false,
  });

  /// Kulübün tercihleri (iyimser: dokunuş önce buraya yazılır).
  final ClubNotificationPrefsModel prefs;

  /// Ayarlar belgesi okundu mu? `false` iken anahtarlar çizilmez.
  final bool isLoaded;

  /// Yazım sürüyor mu?
  final bool isSaving;

  /// Son okuma ya da yazım başarısız mı?
  final bool isError;

  /// [key] anahtarının gösterilen değeri. Sessize alınmış kulüpte üç tür de
  /// kapalı görünür (`sheets.js:38` `cs[k] !== false && !cs.muted`).
  bool valueOf(ClubPrefKey key) => switch (key) {
    ClubPrefKey.announcements => prefs.announcements && !prefs.muted,
    ClubPrefKey.events => prefs.events && !prefs.muted,
    ClubPrefKey.posts => prefs.posts && !prefs.muted,
    ClubPrefKey.muted => prefs.muted,
  };

  /// [key] anahtarı kilitli mi? "Tümünü sessize al" açıkken diğer üçü
  /// kilitlidir (dokunuş TST-X16 gösterir).
  bool isLocked(ClubPrefKey key) => key != ClubPrefKey.muted && prefs.muted;

  @override
  List<Object?> get props => [prefs, isLoaded, isSaving, isError];

  /// Verilen alanları değiştirilmiş kopya.
  ClubNotificationPrefsState copyWith({
    ClubNotificationPrefsModel? prefs,
    bool? isLoaded,
    bool? isSaving,
    bool? isError,
  }) => ClubNotificationPrefsState(
    prefs: prefs ?? this.prefs,
    isLoaded: isLoaded ?? this.isLoaded,
    isSaving: isSaving ?? this.isSaving,
    isError: isError ?? this.isError,
  );
}
