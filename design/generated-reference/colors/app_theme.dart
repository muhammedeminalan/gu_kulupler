// GENERATED — GÜ Kulüpler theme
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'text_theme.dart';

class AppRadius { static const double sm = 12; static const double md = 16; static const double lg = 20; static const double xl = 28; static const double full = 999; }
class AppSpacing { static const List<double> scale = [4, 8, 12, 16, 20, 24, 32, 40, 48]; static const double page = 16; static const double section = 24; static const double card = 16; }
class AppMotion { static const Duration fast = Duration(milliseconds: 120); static const Duration base = Duration(milliseconds: 200); static const Duration slow = Duration(milliseconds: 320); static const Curve standard = Cubic(.2, 0, 0, 1); static const Curve emphasized = Cubic(.3, 0, 0, 1); }

ThemeData _base(ColorScheme cs, Color canvas) => ThemeData(
  useMaterial3: true,
  colorScheme: cs,
  scaffoldBackgroundColor: canvas,
  textTheme: appTextTheme(cs.onSurface),
  cardTheme: CardTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)))),
  inputDecorationTheme: InputDecorationTheme(filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none)),
  bottomSheetTheme: const BottomSheetThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)))),
  dialogTheme: DialogTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
);

final ThemeData lightTheme = _base(const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brandPrimary,
    onPrimary: AppColors.brandOnPrimary,
    primaryContainer: AppColors.brandPrimaryContainer,
    onPrimaryContainer: AppColors.brandOnPrimaryContainer,
    secondary: AppColors.stateInfo,
    onSecondary: AppColors.brandOnPrimary,
    error: AppColors.stateDanger,
    onError: AppColors.brandOnPrimary,
    errorContainer: AppColors.stateDangerContainer,
    surface: AppColors.bgSurface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.bgSurfaceMuted,
    outline: AppColors.borderDefault,
    outlineVariant: AppColors.borderSoft,
    scrim: AppColors.overlayScrim,
  ), AppColors.bgCanvas);
final ThemeData darkTheme = _base(const ColorScheme(
    brightness: Brightness.dark,
    primary: AppColorsDark.brandPrimary,
    onPrimary: AppColorsDark.brandOnPrimary,
    primaryContainer: AppColorsDark.brandPrimaryContainer,
    onPrimaryContainer: AppColorsDark.brandOnPrimaryContainer,
    secondary: AppColorsDark.stateInfo,
    onSecondary: AppColorsDark.brandOnPrimary,
    error: AppColorsDark.stateDanger,
    onError: AppColorsDark.brandOnPrimary,
    errorContainer: AppColorsDark.stateDangerContainer,
    surface: AppColorsDark.bgSurface,
    onSurface: AppColorsDark.textPrimary,
    surfaceContainerHighest: AppColorsDark.bgSurfaceMuted,
    outline: AppColorsDark.borderDefault,
    outlineVariant: AppColorsDark.borderSoft,
    scrim: AppColorsDark.overlayScrim,
  ), AppColorsDark.bgCanvas);
