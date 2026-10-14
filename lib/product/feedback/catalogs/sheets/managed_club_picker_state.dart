import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// SHT-18 "Yönetilen kulüp seç" durumu: yönetilen kulüplerin belgeleri (ad +
/// ikon). Satırların kendisi (hangi kulüp, hangi rol) oturumdan gelir;
/// burası yalnızca kulüp belgelerini taşır.
final class ManagedClubPickerState extends Equatable {
  /// Varsayılan: kulüp yok, okuma sürmüyor.
  const ManagedClubPickerState({
    this.clubs = const <String, ClubModel>{},
    this.isFetching = false,
    this.isError = false,
  });

  /// Okunan kulüpler: kulüp kimliği → belge. Belgesi olmayan ya da silinmiş
  /// kulüp burada yoktur (satırı çizilmez).
  final Map<String, ClubModel> clubs;

  /// Kulüpler okunuyor mu (iskelet)?
  final bool isFetching;

  /// Kulüpler okunamadı mı ("Yeniden dene")?
  final bool isError;

  @override
  List<Object?> get props => [clubs, isFetching, isError];

  /// Verilen alanları değiştirilmiş kopya.
  ManagedClubPickerState copyWith({
    Map<String, ClubModel>? clubs,
    bool? isFetching,
    bool? isError,
  }) => ManagedClubPickerState(
    clubs: clubs ?? this.clubs,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
  );
}
