import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/widgets/feedback/gu_skeleton.dart';

/// Liste durumu (`ui.js:116` `app.sel.listState()`).
enum GuListStatus {
  /// İlk yükleme → iskelet.
  loading,

  /// Yükleme hatası → satır içi hata.
  error,

  /// Veri yok → boş durum.
  empty,

  /// Dolu liste.
  data;

  /// ViewModel `State` bayraklarından durum; öncelik sırası **hata →
  /// yükleniyor → boş → dolu** (CLAUDE.md §4).
  static GuListStatus resolve({
    required bool isError,
    required bool isLoading,
    required bool isEmpty,
  }) {
    if (isError) return GuListStatus.error;
    if (isLoading) return GuListStatus.loading;
    if (isEmpty) return GuListStatus.empty;
    return GuListStatus.data;
  }
}

/// Liste durum anahtarı — prototip `ListState` (`ui.js:115–121`; kompozisyon,
/// CSS sınıfı yok).
///
/// [status]'a göre tek gövde çizer: `error` → [errorBuilder]
/// (`GuErrorState(inline: true)`), `loading` → [skeletonBuilder] ya da
/// `GuSkeletonList(skeletonCount, skeletonVariant)`, `empty` →
/// [emptyBuilder] (`GuEmptyState`), `data` → [dataBuilder]. Metinler
/// builder'ların içinde çağırandan gelir (ARB); varsayılan iskeletin
/// "yükleniyor" etiketi [skeletonSemanticLabel]'dır.
///
/// Çevrimdışı ayrı bir liste durumu değildir: kabuktaki
/// `GuBanner(kind: offline)` üstte kalır, liste önbellekteki veriyle
/// [status]'unu korur (design-contract §6, `states/*__offline.webp`).
class GuListState extends StatelessWidget {
  const GuListState({
    required this.status,
    required this.dataBuilder,
    required this.emptyBuilder,
    required this.errorBuilder,
    this.skeletonBuilder,
    this.skeletonCount = 5,
    this.skeletonVariant = GuSkeletonVariant.tile,
    this.skeletonSemanticLabel,
    super.key,
  }) : assert(
         skeletonBuilder != null || skeletonSemanticLabel != null,
         'Varsayılan iskelet skeletonSemanticLabel ister.',
       );

  /// Çizilecek durum ([GuListStatus.resolve]).
  final GuListStatus status;

  /// Dolu liste.
  final WidgetBuilder dataBuilder;

  /// Boş durum.
  final WidgetBuilder emptyBuilder;

  /// Hata durumu.
  final WidgetBuilder errorBuilder;

  /// Özel iskelet; `null` → `GuSkeletonList`.
  final WidgetBuilder? skeletonBuilder;

  /// Varsayılan iskeletin öğe sayısı (`n = 5`).
  final int skeletonCount;

  /// Varsayılan iskeletin türü.
  final GuSkeletonVariant skeletonVariant;

  /// Varsayılan iskeletin "yükleniyor" etiketi (ARB `commonLoading`).
  final String? skeletonSemanticLabel;

  @override
  Widget build(BuildContext context) => switch (status) {
    GuListStatus.error => errorBuilder(context),
    GuListStatus.loading =>
      skeletonBuilder?.call(context) ??
          GuSkeletonList(
            count: skeletonCount,
            variant: skeletonVariant,
            semanticLabel: skeletonSemanticLabel ?? '',
          ),
    GuListStatus.empty => emptyBuilder(context),
    GuListStatus.data => dataBuilder(context),
  };
}
