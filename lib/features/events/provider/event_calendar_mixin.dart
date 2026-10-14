import 'dart:convert';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/features/events/view/widget/add_to_calendar_sheet.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';

/// Etkinlik bağlantıları: paylaşım adresi ve Google Takvim şablonu
/// (prototip `sheets.js:73`).
abstract final class EventLinks {
  /// [eventId] etkinliğinin paylaşım bağlantısı
  /// (`https://kulupler.gumushane.edu.tr/events/<id>` — K-D).
  static String share(String eventId) =>
      '${AppConstants.shareBaseUrl}${AppPaths.events}/$eventId';

  /// [event] için Google Takvim "etkinlik ekle" şablonu: başlık (`text`),
  /// UTC aralık (`dates`) ve — varsa — [location]. Değerler yüzde kodlanır
  /// (`+` değil).
  static Uri googleCalendar(EventModel event, {String location = ''}) {
    final parameters = <String, String>{
      _action: _template,
      _text: event.title,
      _dates:
          '${IcsBuilder.formatUtc(event.startsAt)}/'
          '${IcsBuilder.formatUtc(event.endsAt)}',
      if (location.isNotEmpty) _location: location,
    };
    return Uri(
      scheme: _https,
      host: _googleHost,
      path: _googlePath,
      query: [
        for (final MapEntry(:key, :value) in parameters.entries)
          '$key=${Uri.encodeComponent(value)}',
      ].join('&'),
    );
  }

  static const String _https = 'https';
  static const String _googleHost = 'calendar.google.com';
  static const String _googlePath = '/calendar/render';
  static const String _action = 'action';
  static const String _template = 'TEMPLATE';
  static const String _text = 'text';
  static const String _dates = 'dates';
  static const String _location = 'location';
}

/// SHT-14 "Takvime ekle" seçiminin yürütülmesi — EVT-02 ve EVT-03
/// ViewModel'leri paylaşır (prototip `sheets.js:73`; K-15, CD-08).
///
/// | Seçim | Yürütme | Geri bildirim |
/// |---|---|---|
/// | `device` | `IcsBuilder.build` → `fileService.writeTemp` → `shareService.shareFile(text/calendar)` | paylaşım açıldıysa TST-36 |
/// | `google` | DLG-32 onayı → `urlLauncherService.open` ([EventLinks.googleCalendar]) | — |
/// | `copyLink` | `shareService.copyText` ([EventLinks.share]) | kopyalandıysa TST-35 |
///
/// Yazma yoktur (çevrimdışı engeli gerekmez).
mixin EventCalendarMixin on ProjectDependencyMixin, ExternalLinkMixin {
  /// [choice] yolunu [event] için yürütür. [clubName] `.ics` açıklamasının
  /// ilk satırı, [placeLabel] mekânın gösterilen adıdır (`EventPlaceLabel`).
  Future<void> addToCalendar(
    CalendarChoice choice, {
    required EventModel event,
    required String clubName,
    required String placeLabel,
  }) async {
    switch (choice) {
      case CalendarChoice.device:
        await exportCalendarFile(
          event: event,
          clubName: clubName,
          placeLabel: placeLabel,
        );
      case CalendarChoice.google:
        await openExternalLink(
          EventLinks.googleCalendar(event, location: placeLabel),
        );
      case CalendarChoice.copyLink:
        if (await shareService.copyText(EventLinks.share(event.id))) {
          feedback.showToast(ToastId.tst35);
        }
    }
  }

  /// "Cihaz takvimi": `.ics` geçici dosyaya yazılır ve sistem paylaşım
  /// sayfasıyla açılır → TST-36. Paylaşıldıysa `true`.
  Future<bool> exportCalendarFile({
    required EventModel event,
    required String clubName,
    required String placeLabel,
  }) async {
    final text = IcsBuilder.build(
      event,
      clubName: clubName,
      location: placeLabel.isEmpty ? null : placeLabel,
    );
    final path = await fileService.writeTemp(
      IcsBuilder.fileNameFor(event),
      utf8.encode(text),
    );
    if (path == null) {
      AppLogger.warn('Takvim dosyası yazılamadı (${event.id})');
      return false;
    }
    final shared = await shareService.shareFile(
      path,
      mimeType: IcsBuilder.mimeType,
    );
    if (shared) feedback.showToast(ToastId.tst36);
    return shared;
  }
}
