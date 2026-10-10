import 'package:equatable/equatable.dart';

/// Etkinlik türü satırı (`StaticTables.eventTypes`; PLAN §4.2, §9.9).
///
/// Statik tablo satırıdır: Firestore'a yazılmaz, JSON dönüşümü yoktur.
/// Görünen ad uygulama katmanında ARB'den çözülür (`eventTypeEgitim` …
/// `eventTypeKonferans`).
final class EventTypeModel extends Equatable {
  /// Etkinlik türü satırı oluşturur.
  const EventTypeModel({required this.id});

  /// Tür kodu (`egitim`, `sosyal`, `gezi`, `yarisma`, `konferans`);
  /// `events.type` bu değeri taşır.
  final String id;

  @override
  List<Object?> get props => [id];

  @override
  bool get stringify => true;
}
