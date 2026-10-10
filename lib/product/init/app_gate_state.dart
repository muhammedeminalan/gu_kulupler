import 'package:equatable/equatable.dart';

/// Kök kapıların durumu (PLAN §12.2): zorunlu güncelleme (DLG-26), oturum
/// sona erdi (DLG-27) ve bakım bandı (CD-48).
final class AppGateState extends Equatable {
  /// Varsayılan: tüm kapılar kapalı.
  const AppGateState({
    this.minSupportedBuild = 0,
    this.currentBuild = 0,
    this.isUpdateRequired = false,
    this.isSessionExpired = false,
    this.maintenanceMessage = '',
    this.isFetching = false,
    this.isError = false,
  });

  /// Remote Config `min_supported_build`; `0` = kapı kapalı.
  final int minSupportedBuild;

  /// Kurulu uygulamanın derleme numarası; `0` = okunamadı.
  final int currentBuild;

  /// Kurulu sürüm desteklenmiyor mu? (DLG-26, kapatılamaz)
  final bool isUpdateRequired;

  /// Oturum sunucu tarafında sona erdi mi? (DLG-27)
  final bool isSessionExpired;

  /// Remote Config `maintenance_message`; boşsa bant çizilmez.
  final String maintenanceMessage;

  /// Remote Config çekimi sürüyor mu?
  final bool isFetching;

  /// Son çekim başarısız mı? Sessizdir: değerler varsayılanlardan devam eder.
  final bool isError;

  /// Bakım bandı gösterilsin mi?
  bool get hasMaintenanceMessage => maintenanceMessage.isNotEmpty;

  @override
  List<Object?> get props => [
    minSupportedBuild,
    currentBuild,
    isUpdateRequired,
    isSessionExpired,
    maintenanceMessage,
    isFetching,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  AppGateState copyWith({
    int? minSupportedBuild,
    int? currentBuild,
    bool? isUpdateRequired,
    bool? isSessionExpired,
    String? maintenanceMessage,
    bool? isFetching,
    bool? isError,
  }) => AppGateState(
    minSupportedBuild: minSupportedBuild ?? this.minSupportedBuild,
    currentBuild: currentBuild ?? this.currentBuild,
    isUpdateRequired: isUpdateRequired ?? this.isUpdateRequired,
    isSessionExpired: isSessionExpired ?? this.isSessionExpired,
    maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
  );
}
