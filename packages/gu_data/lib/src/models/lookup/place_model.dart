import 'package:equatable/equatable.dart';

/// Kampüs mekânı satırı (`StaticTables.places`; PLAN §9.9, domain-model §10).
///
/// Statik tablo satırıdır: Firestore'a yazılmaz, JSON dönüşümü yoktur.
/// Görünen ad uygulama katmanında ARB'den çözülür (`placePl01`–`placePl10`).
final class PlaceModel extends Equatable {
  /// Mekân satırı oluşturur.
  const PlaceModel({required this.id});

  /// Mekân kimliği (`pl01`–`pl10`); `events.placeId` bu değeri taşır.
  final String id;

  @override
  List<Object?> get props => [id];

  @override
  bool get stringify => true;
}
