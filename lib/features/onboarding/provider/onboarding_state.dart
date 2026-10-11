import 'package:equatable/equatable.dart';

/// Tanıtım ekranının durumu (ONB-01; PLAN §12.4).
final class OnboardingState extends Equatable {
  /// Varsayılan: ilk slayt, bitiş başlamadı.
  const OnboardingState({this.pageIndex = 0, this.isFinishing = false});

  /// Slayt sayısı — `discover`, `join`, `follow` (`screens-auth.js:45`).
  static const int pageCount = 3;

  /// Görünen slaytın sırası (`0 … pageCount - 1`).
  final int pageIndex;

  /// "Atla" / "Başla" işleniyor mu (tanıtım bayrağı yazılıyor)?
  final bool isFinishing;

  /// Son slayt mı? (`true` → "İleri" yerine "Başla", `screens-auth.js:50`.)
  bool get isLastPage => pageIndex >= pageCount - 1;

  @override
  List<Object?> get props => [pageIndex, isFinishing];

  /// Verilen alanları değiştirilmiş kopya.
  OnboardingState copyWith({int? pageIndex, bool? isFinishing}) =>
      OnboardingState(
        pageIndex: pageIndex ?? this.pageIndex,
        isFinishing: isFinishing ?? this.isFinishing,
      );
}
