import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:gu_ui/gu_ui.dart';

/// Uygulama tercihleri (PLAN §12.2): tema, dil, metin ölçeği ve ilk açılış
/// bayrakları. Kaynağı `AppPreferencesStore`'dur.
final class AppPreferencesState extends Equatable {
  /// Varsayılanlar: sistem teması, sistem dili, %100 ölçek, bayraklar kapalı.
  const AppPreferencesState({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.textScale = GuTextScaleLevel.s100,
    this.onboardingSeen = false,
    this.notificationPermissionAsked = false,
    this.isLoaded = false,
  });

  /// Tema tercihi (SHT-17).
  final ThemeMode themeMode;

  /// Dil tercihi (SHT-01); `null` = sistem dili.
  final Locale? locale;

  /// Uygulama içi metin ölçeği (SET-01, Q-14).
  final GuTextScaleLevel textScale;

  /// Tanıtım (ONB-01) görüldü mü? Tek kaynak `AppPreferencesStore`'dur;
  /// `SessionState.onboardingSeen` bunun kopyasıdır (CD-52).
  final bool onboardingSeen;

  /// Bildirim izni ön açıklaması (DLG-03) bir kez gösterildi mi?
  final bool notificationPermissionAsked;

  /// Değerler diskten okundu mu? `false` iken uygulama sistem temasıyla açılır.
  final bool isLoaded;

  @override
  List<Object?> get props => [
    themeMode,
    locale,
    textScale,
    onboardingSeen,
    notificationPermissionAsked,
    isLoaded,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearLocale] dili sistem diline
  /// (`null`) döndürür ve [locale]'den önce gelir.
  AppPreferencesState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    GuTextScaleLevel? textScale,
    bool? onboardingSeen,
    bool? notificationPermissionAsked,
    bool? isLoaded,
  }) => AppPreferencesState(
    themeMode: themeMode ?? this.themeMode,
    locale: clearLocale ? null : locale ?? this.locale,
    textScale: textScale ?? this.textScale,
    onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    notificationPermissionAsked:
        notificationPermissionAsked ?? this.notificationPermissionAsked,
    isLoaded: isLoaded ?? this.isLoaded,
  );
}
