import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';

/// Etkinlik mekânının gösterilen adı — prototip `placeName(ev)`: kayıtlı
/// mekân (`placeId` → ARB, `StaticLabels.place`) ya da serbest metin
/// (`placeText`). İkisi de yoksa boş.
abstract final class EventPlaceLabel {
  /// [event] mekânının adı.
  static String of(BuildContext context, EventModel event) {
    final placeId = event.placeId;
    if (placeId != null) return StaticLabels.place(context, placeId);
    return event.placeText ?? '';
  }
}
