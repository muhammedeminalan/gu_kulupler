import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:gu_ui/gu_ui.dart';

/// DebugMenu panelinin durumu (K-E, CD-69; PLAN §12.3): görünüm tercihleri
/// `AppPreferencesState`'ten yansıtılır; demo hesap girişi (yalnızca
/// emülatör) kendi alanlarını tutar.
final class DebugMenuState extends Equatable {
  /// Varsayılan: sistem teması, sistem dili, %100 ölçek; süren giriş ve hata
  /// yok.
  const DebugMenuState({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.textScale = GuTextScaleLevel.s100,
    this.signingInId,
    this.isError = false,
    this.errorCode,
  });

  /// Tema tercihi.
  final ThemeMode themeMode;

  /// Dil tercihi; `null` = sistem dili.
  final Locale? locale;

  /// Uygulama içi metin ölçeği.
  final GuTextScaleLevel textScale;

  /// Girişi süren demo hesabın kimliği (`u_ayse` …); süren giriş yoksa
  /// `null`.
  final String? signingInId;

  /// Son demo hesap girişi başarısız mı?
  final bool isError;

  /// Son giriş hatasının kodu (`AuthError.name`); hata yoksa `null`.
  final String? errorCode;

  @override
  List<Object?> get props => [
    themeMode,
    locale,
    textScale,
    signingInId,
    isError,
    errorCode,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearLocale] dili sistem diline
  /// (`null`) döndürür ve [locale]'den önce gelir; [clearSigningInId] ve
  /// [clearErrorCode] aynı biçimde ilgili alanı `null` yapar.
  DebugMenuState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    GuTextScaleLevel? textScale,
    String? signingInId,
    bool clearSigningInId = false,
    bool? isError,
    String? errorCode,
    bool clearErrorCode = false,
  }) => DebugMenuState(
    themeMode: themeMode ?? this.themeMode,
    locale: clearLocale ? null : locale ?? this.locale,
    textScale: textScale ?? this.textScale,
    signingInId: clearSigningInId ? null : signingInId ?? this.signingInId,
    isError: isError ?? this.isError,
    errorCode: clearErrorCode ? null : errorCode ?? this.errorCode,
  );
}
