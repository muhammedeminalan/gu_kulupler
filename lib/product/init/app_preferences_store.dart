import 'dart:convert';

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:gu_data/gu_data.dart' show Limits;
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihazda saklanan kullanıcı tercihleri ve ilk açılış bayrakları (D-24,
/// Q-14, CD-52). Tek ad: `AppPreferencesService` / `AppInitFlags` yoktur.
///
/// - Okuyucular eşzamanlıdır; [load] tamamlanmadan varsayılanları döndürür.
/// - Yazıcılar **hiçbir zaman fırlatmaz**: kalıcılık hatası `false` döner
///   (çağıran günlüğe yazar; kullanıcıya gösterilmez).
/// - Yazı taslakları (FED-03) kulüp başına tek kayıttır ([composeDraft] —
///   CD-45).
abstract interface class AppPreferencesStore {
  /// Değerler diskten okundu mu?
  bool get isLoaded;

  /// Değerleri diskten okur. Fırlatmaz: okunamazsa
  /// varsayılanlar geçerli kalır ve [isLoaded] `false` kalır.
  Future<void> load();

  /// Tema tercihi; varsayılan [ThemeMode.system].
  ThemeMode get themeMode;

  /// Dil tercihi; `null` = sistem dili.
  Locale? get locale;

  /// Uygulama içi metin ölçeği; varsayılan [GuTextScaleLevel.s100].
  GuTextScaleLevel get textScale;

  /// Tanıtım (ONB-01) görüldü mü? (`pref.onboardingSeen`)
  bool get onboardingSeen;

  /// Bildirim izni ön açıklaması (DLG-03) bir kez gösterildi mi?
  bool get notificationPermissionAsked;

  /// Fotoğraf erişimi ön açıklaması (DLG-05) onaylandı mı? Galeri sistem
  /// seçicisiyle açıldığından (CD-16) sistem izni yoktur; onay cihazda
  /// tutulur ve açıklama bir daha gösterilmez.
  bool get photoAccessExplained;

  /// Son aramalar (CLB-02), en yeni önde; en çok `Limits.recentSearchesMax`.
  /// Dönen liste değiştirilemez.
  List<String> get recentSearches;

  /// Bu cihazın push jetonunun en son yazıldığı hesap (T-42 güvenlik
  /// incelemesi): başka hesap girince jeton önce geçersiz kılınır —
  /// çevrimdışı çıkışta önceki hesapta kalan jeton yeni hesaba taşınmaz.
  String? get pushTokenUid;

  /// Tema tercihini yazar.
  Future<bool> setThemeMode(ThemeMode mode);

  /// Dil tercihini yazar; `null` sistem diline döner.
  Future<bool> setLocale(Locale? locale);

  /// Metin ölçeğini yazar.
  Future<bool> setTextScale(GuTextScaleLevel level);

  /// Tanıtım bayrağını yazar.
  Future<bool> setOnboardingSeen(bool value);

  /// Bildirim izni bayrağını yazar.
  Future<bool> setNotificationPermissionAsked(bool value);

  /// Fotoğraf erişimi açıklaması bayrağını yazar.
  Future<bool> setPhotoAccessExplained(bool value);

  /// Son aramaları [terms] ile değiştirir (en yeni önde); fazlası
  /// `Limits.recentSearchesMax`'te kesilir. Boş liste geçmişi temizler.
  Future<bool> setRecentSearches(List<String> terms);

  /// Push jetonunun yazıldığı hesabı kaydeder; `null` kaydı kaldırır.
  Future<bool> setPushTokenUid(String? uid);

  /// [clubId] kulübü için saklanan yazı taslağı (FED-03; CD-45): çağıranın
  /// yazdığı JSON metni, taslak yoksa `null`. Kulüp başına **tek** taslak
  /// tutulur; içeriği bu depo yorumlamaz.
  String? composeDraft(String clubId);

  /// [clubId] kulübünün yazı taslağını [json] ile değiştirir; `null` taslağı
  /// kaldırır (yayın ya da "Kaydetmeden çık" sonrası).
  Future<bool> setComposeDraft(String clubId, String? json);

  /// [uid] hesabının hatırlatıcı eşitlemesinde bir daha okunması gerekmeyen
  /// `going` etkinlikleri (bitmiş ya da iptal — T-44 · D2-06). Hesap
  /// başınadır; yoksa boş küme.
  Set<String> reminderDoneEvents(String uid);

  /// [uid] hesabının bitmiş etkinlik kümesini [eventIds] ile değiştirir.
  Future<bool> setReminderDoneEvents(String uid, Set<String> eventIds);

  /// Storage görsel yolu → indirme adresi ve alındığı an (UTC; T-44 · D2-05).
  /// Soğuk açılışta görsel yer tutucuya düşmeden, çevrimdışında diskteki
  /// kopyadan çizilir. Bozuk ya da okunamayan kayıt boş haritadır.
  Map<String, ({String url, DateTime at})> get imageUrls;

  /// Görsel adreslerini [entries] ile değiştirir; en yeni
  /// `MediaConstants.imageUrlPersistMaxEntries` kayıt tutulur.
  Future<bool> setImageUrls(Map<String, ({String url, DateTime at})> entries);
}

/// `shared_preferences` anahtarları — tek liste (PLAN §4.4, §12.2).
abstract final class AppPreferenceKeys {
  /// Tema: `system` / `light` / `dark`.
  static const String themeMode = 'pref.themeMode';

  /// Dil kodu (`tr` / `en`); boş = sistem dili.
  static const String locale = 'pref.locale';

  /// Metin ölçeği: `s100` / `s130` / `s160`.
  static const String textScale = 'pref.textScale';

  /// Tanıtım görüldü mü.
  static const String onboardingSeen = 'pref.onboardingSeen';

  /// Bildirim izni ön açıklaması gösterildi mi.
  static const String notificationPermissionAsked =
      'pref.notificationPermissionAsked';

  /// Fotoğraf erişimi ön açıklaması (DLG-05) onaylandı mı.
  static const String photoAccessExplained = 'pref.photoAccessExplained';

  /// Son aramalar (CLB-02): metin listesi, en yeni önde.
  static const String recentSearches = 'pref.recentSearches';

  /// Push jetonunun en son yazıldığı hesabın uid'i (T-42).
  static const String pushTokenUid = 'pref.pushTokenUid';

  /// [clubId] kulübünün yazı taslağı (FED-03): JSON metni —
  /// `compose_draft_<clubId>` (CD-45).
  static String composeDraft(String clubId) => 'compose_draft_$clubId';

  /// [uid] hesabının hatırlatıcıda bitmiş etkinlikleri (T-44 · D2-06): metin
  /// listesi.
  static String reminderDone(String uid) => 'pref.reminderDone.$uid';

  /// Görsel yolu → indirme adresi (T-44 · D2-05): JSON
  /// `{yol: [adres, alındığıAnMsUtc]}`.
  static const String imageUrls = 'media.imageUrls';
}

/// [AppPreferencesStore.imageUrls] JSON kodlaması (`{yol: [adres, msUtc]}`);
/// gerçek depo ve test çifti aynı kodu kullanır.
abstract final class ImageUrlsCodec {
  /// [json] metnini çözer; bozuk metin ya da tanınmayan kayıt atlanır
  /// (fırlatmaz).
  static Map<String, ({String url, DateTime at})> decode(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) return const {};
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (value case [final String url, final int ms])
            key: (
              url: url,
              at: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
            ),
      };
    } on FormatException {
      return const {};
    }
  }

  /// [entries] içinden en yeni [max] kaydı JSON'a çevirir.
  static String encode(
    Map<String, ({String url, DateTime at})> entries, {
    int max = MediaConstants.imageUrlPersistMaxEntries,
  }) {
    final newest = entries.entries.toList()
      ..sort((a, b) => b.value.at.compareTo(a.value.at));
    return jsonEncode({
      for (final MapEntry(:key, :value) in newest.take(max))
        key: [value.url, value.at.toUtc().millisecondsSinceEpoch],
    });
  }
}

/// [AppPreferencesStore] uygulaması: `shared_preferences`.
///
/// Bozuk ya da tanınmayan değer (elle değiştirilmiş, eski sürümden kalma)
/// varsayılana düşer; desteklenmeyen dil kodu sistem dili sayılır.
final class SharedAppPreferencesStore implements AppPreferencesStore {
  /// `open` verilmezse `SharedPreferences.getInstance` kullanılır.
  SharedAppPreferencesStore({
    this._open = SharedPreferences.getInstance,
  });

  final Future<SharedPreferences> Function() _open;
  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  GuTextScaleLevel _textScale = GuTextScaleLevel.s100;
  bool _onboardingSeen = false;
  bool _notificationPermissionAsked = false;
  bool _photoAccessExplained = false;
  List<String> _recentSearches = const <String>[];
  String? _pushTokenUid;

  /// Bu oturumda yazılan / kaldırılan taslaklar (kulüp → JSON; `null` =
  /// kaldırıldı). Diskteki değerin önüne geçer: yazım başarısız olsa da
  /// oturum boyunca geçerlidir.
  final Map<String, String?> _composeDrafts = <String, String?>{};

  /// Bu oturumda yazılan bitmiş etkinlik kümeleri (uid → küme); diskteki
  /// değerin önüne geçer.
  final Map<String, Set<String>> _reminderDone = <String, Set<String>>{};

  /// Görsel adresleri: ilk okumada diskten çözülür, yazımda güncellenir.
  Map<String, ({String url, DateTime at})>? _imageUrls;

  @override
  bool get isLoaded => _prefs != null;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Locale? get locale => _locale;

  @override
  GuTextScaleLevel get textScale => _textScale;

  @override
  bool get onboardingSeen => _onboardingSeen;

  @override
  bool get notificationPermissionAsked => _notificationPermissionAsked;

  @override
  bool get photoAccessExplained => _photoAccessExplained;

  @override
  List<String> get recentSearches => _recentSearches;

  @override
  String? get pushTokenUid => _pushTokenUid;

  @override
  Future<void> load() async {
    try {
      final prefs = await _open();
      _themeMode = _enumOf(
        ThemeMode.values,
        _string(prefs, AppPreferenceKeys.themeMode),
        ThemeMode.system,
      );
      _locale = _localeOf(_string(prefs, AppPreferenceKeys.locale));
      _textScale = _enumOf(
        GuTextScaleLevel.values,
        _string(prefs, AppPreferenceKeys.textScale),
        GuTextScaleLevel.s100,
      );
      _onboardingSeen = _bool(prefs, AppPreferenceKeys.onboardingSeen);
      _notificationPermissionAsked = _bool(
        prefs,
        AppPreferenceKeys.notificationPermissionAsked,
      );
      _photoAccessExplained = _bool(
        prefs,
        AppPreferenceKeys.photoAccessExplained,
      );
      _recentSearches = _capped(
        _stringList(prefs, AppPreferenceKeys.recentSearches),
      );
      _pushTokenUid = _string(prefs, AppPreferenceKeys.pushTokenUid);
      _prefs = prefs;
    } on Object catch (error, stack) {
      AppLogger.warn('Tercihler okunamadı', error: error, stackTrace: stack);
    }
  }

  @override
  Future<bool> setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    return _write(
      (prefs) => prefs.setString(AppPreferenceKeys.themeMode, mode.name),
    );
  }

  @override
  Future<bool> setLocale(Locale? locale) {
    _locale = locale;
    return _write(
      (prefs) => prefs.setString(
        AppPreferenceKeys.locale,
        locale?.languageCode ?? '',
      ),
    );
  }

  @override
  Future<bool> setTextScale(GuTextScaleLevel level) {
    _textScale = level;
    return _write(
      (prefs) => prefs.setString(AppPreferenceKeys.textScale, level.name),
    );
  }

  @override
  Future<bool> setOnboardingSeen(bool value) {
    _onboardingSeen = value;
    return _write(
      (prefs) => prefs.setBool(AppPreferenceKeys.onboardingSeen, value),
    );
  }

  @override
  Future<bool> setNotificationPermissionAsked(bool value) {
    _notificationPermissionAsked = value;
    return _write(
      (prefs) =>
          prefs.setBool(AppPreferenceKeys.notificationPermissionAsked, value),
    );
  }

  @override
  Future<bool> setPhotoAccessExplained(bool value) {
    _photoAccessExplained = value;
    return _write(
      (prefs) => prefs.setBool(AppPreferenceKeys.photoAccessExplained, value),
    );
  }

  @override
  Future<bool> setRecentSearches(List<String> terms) {
    final capped = _recentSearches = _capped(terms);
    return _write(
      (prefs) => prefs.setStringList(AppPreferenceKeys.recentSearches, capped),
    );
  }

  @override
  Future<bool> setPushTokenUid(String? uid) {
    _pushTokenUid = uid;
    return _write(
      (prefs) => uid == null
          ? prefs.remove(AppPreferenceKeys.pushTokenUid)
          : prefs.setString(AppPreferenceKeys.pushTokenUid, uid),
    );
  }

  @override
  String? composeDraft(String clubId) {
    if (_composeDrafts.containsKey(clubId)) return _composeDrafts[clubId];
    final prefs = _prefs;
    return prefs == null
        ? null
        : _string(prefs, AppPreferenceKeys.composeDraft(clubId));
  }

  @override
  Future<bool> setComposeDraft(String clubId, String? json) {
    _composeDrafts[clubId] = json;
    final key = AppPreferenceKeys.composeDraft(clubId);
    return _write(
      (prefs) => json == null ? prefs.remove(key) : prefs.setString(key, json),
    );
  }

  @override
  Set<String> reminderDoneEvents(String uid) {
    if (_reminderDone[uid] case final known?) return Set.unmodifiable(known);
    final prefs = _prefs;
    if (prefs == null) return const {};
    return Set.unmodifiable(
      _stringList(prefs, AppPreferenceKeys.reminderDone(uid)),
    );
  }

  @override
  Future<bool> setReminderDoneEvents(String uid, Set<String> eventIds) {
    final ids = _reminderDone[uid] = Set.of(eventIds);
    return _write(
      (prefs) => prefs.setStringList(
        AppPreferenceKeys.reminderDone(uid),
        ids.toList(),
      ),
    );
  }

  @override
  Map<String, ({String url, DateTime at})> get imageUrls {
    if (_imageUrls case final known?) return known;
    final prefs = _prefs;
    if (prefs == null) return const {};
    return _imageUrls = Map.unmodifiable(
      ImageUrlsCodec.decode(_string(prefs, AppPreferenceKeys.imageUrls)),
    );
  }

  @override
  Future<bool> setImageUrls(Map<String, ({String url, DateTime at})> entries) {
    final json = ImageUrlsCodec.encode(entries);
    _imageUrls = Map.unmodifiable(ImageUrlsCodec.decode(json));
    return _write(
      (prefs) => prefs.setString(AppPreferenceKeys.imageUrls, json),
    );
  }

  /// [write] yazımını çalıştırır; depo açılamadıysa ya da yazım başarısızsa
  /// `false` (bellekteki değer oturum boyunca geçerli kalır).
  Future<bool> _write(
    Future<bool> Function(SharedPreferences prefs) write,
  ) async {
    try {
      final prefs = _prefs ??= await _open();
      return await write(prefs);
    } on Object catch (error, stack) {
      AppLogger.warn('Tercih yazılamadı', error: error, stackTrace: stack);
      return false;
    }
  }

  /// [key] metin değilse (tip uyuşmazlığı) `null`.
  static String? _string(SharedPreferences prefs, String key) =>
      switch (prefs.get(key)) {
        final String value => value,
        _ => null,
      };

  static bool _bool(SharedPreferences prefs, String key) =>
      switch (prefs.get(key)) {
        final bool value => value,
        _ => false,
      };

  /// [key] metin listesi değilse (tip uyuşmazlığı) boş liste.
  static List<String> _stringList(SharedPreferences prefs, String key) =>
      switch (prefs.get(key)) {
        final List<Object?> values => values.whereType<String>().toList(),
        _ => const <String>[],
      };

  /// En çok `Limits.recentSearchesMax` öğe, değiştirilemez liste.
  static List<String> _capped(List<String> terms) =>
      List<String>.unmodifiable(terms.take(Limits.recentSearchesMax));

  static T _enumOf<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  /// Yalnızca desteklenen dil kodları tercih sayılır.
  static Locale? _localeOf(String? code) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == code) return Locale(locale.languageCode);
    }
    return null;
  }
}
