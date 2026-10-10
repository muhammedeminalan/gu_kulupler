import 'package:equatable/equatable.dart';

/// Bağlantı durumu (PLAN §12.2): kök çevrimdışı bandının (SYS-03) ve tam
/// ekran çevrimdışı görünümünün kaynağı.
final class ConnectivityState extends Equatable {
  /// Varsayılan: çevrimiçi.
  const ConnectivityState({
    this.isOffline = false,
    this.isFromCache = false,
    this.wasOffline = false,
    this.isSimulated = false,
  });

  /// Cihaz çevrimdışı mı (gerçek ya da simüle)?
  final bool isOffline;

  /// Ekrandaki veri Firestore önbelleğinden mi geliyor? Tam ekran çevrimdışı
  /// koşulu `isOffline && liste boş && !isFromCache`'tir (PLAN §12.1).
  final bool isFromCache;

  /// Bu oturumda en az bir kez çevrimdışı olundu mu? (TST-25 yalnızca
  /// çevrimdışından dönüşte gösterilir.)
  final bool wasOffline;

  /// Çevrimdışılık DebugMenu simülasyonu mu?
  final bool isSimulated;

  @override
  List<Object?> get props => [isOffline, isFromCache, wasOffline, isSimulated];

  /// Verilen alanları değiştirilmiş kopya.
  ConnectivityState copyWith({
    bool? isOffline,
    bool? isFromCache,
    bool? wasOffline,
    bool? isSimulated,
  }) => ConnectivityState(
    isOffline: isOffline ?? this.isOffline,
    isFromCache: isFromCache ?? this.isFromCache,
    wasOffline: wasOffline ?? this.wasOffline,
    isSimulated: isSimulated ?? this.isSimulated,
  );
}
