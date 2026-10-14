import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';

/// İstemci tarafı etkinlik havuzu birleştirmesi — EVT-01
/// (`EventListViewModel`) ve CLB-02 "Etkinlikler" sekmesi
/// (`SearchViewModel`) aynı kuralı kullanır: herkese açık sorgu + üye olunan
/// kulüp başına üyelere özel sorgu tek listeye iner.
abstract final class EventPool {
  /// Sorgu sonuçlarını birleştirir: başarısız sorgu [logLabel] ile günlüğe
  /// düşer ve atlanır; aynı etkinlik bir kez; yalnızca [clubIds]
  /// kulüplerinin (havuzdaki etkin kulüpler) etkinlikleri; başlangıca göre
  /// artan, eşitlikte kimliğe göre (kararlı sıra).
  static List<EventModel> merge({
    required Set<String> clubIds,
    required List<FirestoreResult<List<EventModel>>> results,
    required String logLabel,
  }) {
    final byId = <String, EventModel>{};
    for (final result in results) {
      switch (result) {
        case FirebaseSuccess(:final data):
          for (final event in data) {
            if (clubIds.contains(event.clubId)) byId[event.id] = event;
          }
        case FirebaseFailure(:final error, :final message):
          AppLogger.warn('$logLabel: ${error.name}', error: message);
      }
    }
    return byId.values.toList()..sort((a, b) {
      final byStart = a.startsAt.compareTo(b.startsAt);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    });
  }
}
