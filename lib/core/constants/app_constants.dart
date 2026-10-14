import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:gu_data/gu_data.dart';

/// Ürün adı ve dış adresler için TEK kaynak (D-01, K-D, K-N, CD-75, CD-76).
///
/// Başka hiçbir dosyada ürün adı, alan adı, URL ya da destek adresi literal
/// olarak yazılmaz; ARB metinleri `{appName}` / `{appNameDative}` yer
/// tutucularını bu sabitlerden alır.
abstract final class AppConstants {
  /// Ürün adı (brief K1; `CFBundleDisplayName` ve `android:label` ile parite testi).
  static const String appName = 'GÜ Kulüpler';

  /// Türkçe yönelme hâli ("…’e hoş geldin"); ad değişince `appName` ile birlikte güncellenir.
  static const String appNameDative = 'GÜ Kulüpler’e';

  /// İzinli e-posta alan adları (D-27). Tek kaynak `gu_data`
  /// `EmailDomainPolicy.allowedDomains`'tir; bu alan ona delege eder, ikinci
  /// kopya tutulmaz (CD-76).
  static const List<String> allowedEmailDomains =
      EmailDomainPolicy.allowedDomains;

  /// Paylaşım bağlantısı kökü (K-09 yer tutucu; yalnızca kopyala/paylaş, App Links yok).
  static const String shareBaseUrl = 'https://kulupler.gumushane.edu.tr';

  /// Destek e-postası (DLG-01 mailto, SET-04; yer tutucu — K-N).
  static const String supportEmail = 'kulupler-destek@gumushane.edu.tr';

  /// [supportEmail] adresine e-posta açan bağlantı (`UrlLauncherService.open`;
  /// DLG-01 "Destekle iletişime geç", SET-04 / SET-05).
  static Uri get supportMailUri => Uri(scheme: _mailScheme, path: supportEmail);

  /// Android uygulama kimliği (`android/app/build.gradle.kts`
  /// `applicationId` ile parite testi); Google Play adresinde kullanılır.
  static const String androidApplicationId = 'com.gukulupler.gu_kulupler';

  /// App Store uygulama kimliği (`apps.apple.com/app/id…`).
  // TODO(T-46): yer tutucu — App Store Connect kaydı açılınca gerçek kimlik
  // yazılır (mağaza ve yayın hazırlığı).
  static const String appStoreId = '0000000000';

  /// Uygulamanın [platform] mağazasındaki sayfası (DLG-26 "Güncelle";
  /// `UrlLauncherService.open`). Apple platformlarında App Store, diğerlerinde
  /// Google Play.
  static Uri storeUri(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => Uri.https(
      _appStoreHost,
      '/app/id$appStoreId',
    ),
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => Uri.https(_playStoreHost, _playStorePath, {
      _playStoreIdParameter: androidApplicationId,
    }),
  };

  /// Yerel etkinlik hatırlatıcısının Android bildirim kanalı kimliği (Q-07,
  /// PLAN §14.10, §15.6 — tek tanım; kanal adı ARB `eventReminder`).
  static const String reminderChannelId = 'event_reminders';

  /// Hatırlatıcı seçeneklerinin başlangıçtan önceki süreleri (CD-34;
  /// `LocalReminderService.leadTimeOf`). `ReminderOption.none` süresizdir.
  static const Map<ReminderOption, Duration> reminderLeadTimes = {
    ReminderOption.fifteenMinutes: Duration(minutes: 15),
    ReminderOption.oneHour: Duration(hours: 1),
    ReminderOption.oneDay: Duration(days: 1),
  };

  /// Bir takvim günü (Istanbul günü aralıkları; UTC+3 sabit, DST yok —
  /// domain-model §1.5).
  static const Duration calendarDay = Duration(days: 1);

  /// SHT-11 / EVT-01 "Bu hafta": bugünden itibaren 7 gün (prototip
  /// `t0 + 7 * DAY`, `screens-events.js:10`).
  static const Duration eventWeekSpan = Duration(days: 7);

  /// SHT-11 "Bu ay": bugünden itibaren 30 gün (prototip `t0 + 30 * DAY`,
  /// `screens-events.js:10`).
  static const Duration eventMonthSpan = Duration(days: 30);

  static const String _mailScheme = 'mailto';
  static const String _appStoreHost = 'apps.apple.com';
  static const String _playStoreHost = 'play.google.com';
  static const String _playStorePath = '/store/apps/details';
  static const String _playStoreIdParameter = 'id';
}
